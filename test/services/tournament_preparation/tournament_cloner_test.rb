# frozen_string_literal: true

require "test_helper"

module TournamentPreparation
  # Regression zur Klon-Welle vom August 2026: 36 NBV-Karambol-Turniere entstanden ohne
  # Turnierplan, weil tpid aus dem lokalen `tournament_plan_cc_id` (bei NBV durchweg 1)
  # statt aus der CC-ID gebildet wurde. Die ClubCloud verwarf die unbekannte ID still.
  # In der CC ist das nachträglich nicht korrigierbar — das Turnier muss neu angelegt
  # werden. Deshalb bricht der Klon lieber ab, als eine ungeprüfte tpid zu senden.
  class TournamentClonerTest < ActiveSupport::TestCase
    PlanDouble = Struct.new(:name, :context, :cc_id)
    TournamentCcDouble = Struct.new(:tournament_plan_cc)

    def cloner(opts: {})
      TournamentCloner.new(source_tournament: nil, opts: opts)
    end

    test "sendet die CC-ID des Turnierplans, nicht den lokalen Fremdschluessel" do
      tc = TournamentCcDouble.new(PlanDouble.new("CC: UNIVERSAL", "nbv", 1000))

      assert_equal 1000, cloner.send(:resolve_tpid, tc)
    end

    test "bricht ab, wenn der Turnierplan keine CC-ID hat" do
      tc = TournamentCcDouble.new(PlanDouble.new("CC: UNIVERSAL", "nbv", nil))

      error = assert_raises(RuntimeError) { cloner.send(:resolve_tpid, tc) }
      assert_match(/CC-ID/, error.message)
      assert_match(/CC: UNIVERSAL/, error.message)
    end

    test "bricht ab, wenn das Quell-Turnier gar keinen Turnierplan hat" do
      tc = TournamentCcDouble.new(nil)

      error = assert_raises(RuntimeError) { cloner.send(:resolve_tpid, tc) }
      assert_match(/keinen Turnierplan/, error.message)
    end

    test "bricht ab, wenn gar kein tournament_cc vorliegt" do
      assert_raises(RuntimeError) { cloner.send(:resolve_tpid, nil) }
    end

    test "opts tpid uebersteuert den Guard bewusst" do
      tc = TournamentCcDouble.new(PlanDouble.new("CC: UNIVERSAL", "nbv", nil))

      assert_equal 1234, cloner(opts: {tpid: 1234}).send(:resolve_tpid, tc)
    end

    # ── Rückleseprüfung des Turnierplans ──────────────────────────────────────
    #
    # Der Guard oben verhindert, dass eine LEERE cc_id gesendet wird. Er kann aber nicht
    # wissen, ob die gesendete ID in DIESER ClubCloud gilt — fremde Verbände vergeben eigene
    # Nummern, und die CC speichert eine unbekannte tpid stillschweigend. Deshalb wird der
    # gesetzte Plan nach dem Anlegen von der Detailseite zurueckgelesen.

    # Liefert genau das, was RegionCc#get_cc liefert: [response, Nokogiri-Doc].
    RegionCcDouble = Struct.new(:html) do
      def get_cc(_action, _opts = {}, _o = {})
        [nil, Nokogiri::HTML(html)]
      end
    end

    def detail_page(plan_html)
      <<~HTML
        <table><tr class="tableContent"><td><table>
          <tr><td>Datum</td><td></td><td>19.09.2026</td></tr>
          <tr><td>Turnierplan</td><td></td><td>#{plan_html}</td></tr>
        </table></td></tr></table>
      HTML
    end

    test "passender Turnierplan wird als verifiziert gemeldet" do
      region_cc = RegionCcDouble.new(detail_page("<b>CC: UNIVERSAL</b>"))

      result = cloner.send(:verify_tournament_plan, region_cc, "20-1-2-3-4-5-942", "CC: UNIVERSAL")

      assert_equal true, result[:ok]
      assert_equal "CC: UNIVERSAL", result[:gelesen]
    end

    test "leeres Turnierplan-Feld ist ein Fehler — genau der Befund der Klon-Welle" do
      region_cc = RegionCcDouble.new(detail_page(""))

      result = cloner.send(:verify_tournament_plan, region_cc, "20-1-2-3-4-5-942", "CC: UNIVERSAL")

      assert_equal false, result[:ok]
      assert_nil result[:gelesen]
      assert_match(/LEER/, result[:hinweis])
    end

    test "abweichender Turnierplan ist ein Fehler" do
      region_cc = RegionCcDouble.new(detail_page("<b>DKO-016</b>"))

      result = cloner.send(:verify_tournament_plan, region_cc, "20-1-2-3-4-5-942", "CC: UNIVERSAL")

      assert_equal false, result[:ok]
      assert_equal "DKO-016", result[:gelesen]
      assert_match(/anderen Plan/, result[:hinweis])
    end

    test "ohne p-Parameter ist die Pruefung nicht moeglich, aber kein Fehler" do
      result = cloner.send(:verify_tournament_plan, RegionCcDouble.new(detail_page("<b>x</b>")), nil, "CC: UNIVERSAL")

      assert_nil result[:ok]
      assert_match(/Detailseite/, result[:hinweis])
    end

    test "bei tpid-Override wird gelesen, aber nicht bewertet" do
      region_cc = RegionCcDouble.new(detail_page("<b>DKO-016</b>"))

      result = cloner.send(:verify_tournament_plan, region_cc, "20-1-2-3-4-5-942", nil)

      assert_nil result[:ok]
      assert_equal "DKO-016", result[:gelesen]
      assert_match(/kein Sollwert/, result[:hinweis])
    end
  end
end
