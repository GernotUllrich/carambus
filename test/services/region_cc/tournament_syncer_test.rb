# frozen_string_literal: true

require "test_helper"

# Unit tests fuer RegionCc::TournamentSyncer.
# Alle HTTP-Aufrufe werden via Minitest::Mock abgefangen.
# Kein VCR — reine Unit-Tests mit injizierten Client-Doubles.
class RegionCc::TournamentSyncerTest < ActiveSupport::TestCase
  setup do
    @region_cc = RegionCc.new(cc_id: 20, shortname: "NBV")
    @client = Minitest::Mock.new
  end

  # ---------------------------------------------------------------------------
  # Test 1: sync_tournament_ccs liest showMeisterschaftenList und gibt TournamentCc-Records zurueck
  # ---------------------------------------------------------------------------
  test "sync_tournament_ccs calls post with showMeisterschaftenList action" do
    # Minimales HTML: keine Turniere, kein errMsg => leere Ergebnisliste
    stub_html = <<~HTML
      <html><body>
        <input name="errMsg" value="">
      </body></html>
    HTML

    branch_cc = BranchCc.new(cc_id: 6, name: "Karambol")
    region_cc_stub = RegionCc.new(cc_id: 20)
    region_stub = Region.new
    region_stub.define_singleton_method(:cc_id) { 20 }
    region_stub.define_singleton_method(:region_cc) { region_cc_stub }
    season = Season.new(id: 5, name: "2023/2024")
    region_cc_stub.define_singleton_method(:branch_ccs) { [branch_cc] }

    @client.expect(:post, [OpenStruct.new(message: "OK"), Nokogiri::HTML(stub_html)],
      ["showMeisterschaftenList", Hash, Hash])

    Region.stub(:find_by_shortname, region_stub) do
      Season.stub(:find_by_name, season) do
        result = nil
        assert_nothing_raised do
          result = RegionCc::TournamentSyncer.call(
            region_cc: @region_cc, client: @client,
            operation: :sync_tournament_ccs,
            context: "nbv", season_name: "2023/2024"
          )
        end
        # Dispatcher hat den richtigen Zweig durchlaufen
        assert_kind_of Array, result
      end
    end

    @client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 2: sync_tournament_series_ccs liest showSerienList
  # ---------------------------------------------------------------------------
  test "sync_tournament_series_ccs calls post with showSerienList action" do
    stub_html = <<~HTML
      <html><body>
        <select name="serienId">
        </select>
      </body></html>
    HTML

    branch_cc = BranchCc.new(cc_id: 10, name: "Karambol")
    region_cc_stub = RegionCc.new(cc_id: 20)
    region_stub = Region.new
    region_stub.define_singleton_method(:region_cc) { region_cc_stub }
    region_cc_stub.define_singleton_method(:branch_ccs) { [branch_cc] }
    season = Season.new(id: 5, name: "2023/2024")

    @client.expect(:post, [OpenStruct.new(message: "OK"), Nokogiri::HTML(stub_html)],
      ["showSerienList", Hash, Hash])

    Region.stub(:find_by_shortname, region_stub) do
      Season.stub(:find_by_name, season) do
        result = nil
        assert_nothing_raised do
          result = RegionCc::TournamentSyncer.call(
            region_cc: @region_cc, client: @client,
            operation: :sync_tournament_series_ccs,
            context: "nbv", season_name: "2023/2024"
          )
        end
        # Dispatcher hat den richtigen Zweig durchlaufen
        assert_kind_of Array, result
      end
    end

    @client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 3: fix_tournament_structure behandelt fehlendes Tournament ohne Exception
  # ---------------------------------------------------------------------------
  test "fix_tournament_structure handles missing TournamentCc gracefully" do
    season = Season.new(id: 5, name: "2023/2024")
    region = Region.new
    region.define_singleton_method(:id) { 1 }
    region.define_singleton_method(:shortname) { "NBV" }
    @region_cc.define_singleton_method(:region) { region }

    # Kein TournamentCc => error geloggt, kein Crash
    tournament = Tournament.new
    tournament.define_singleton_method(:id) { 42 }
    tournament.define_singleton_method(:title) { "Test Turnier" }
    discipline = Discipline.new
    root_discipline = Discipline.new
    root_discipline.define_singleton_method(:name) { "Karambol" }
    root_discipline.define_singleton_method(:branch_cc) { BranchCc.new(cc_id: 6) }
    discipline.define_singleton_method(:root) { root_discipline }
    tournament.define_singleton_method(:discipline) { discipline }

    tournament_scope = [tournament]
    def tournament_scope.where(*args)
      self
    end

    def tournament_scope.not(*args)
      self
    end

    def tournament_scope.to_a
      self
    end

    Season.stub(:find_by_name, season) do
      Tournament.stub(:where, tournament_scope) do
        TournamentCc.stub(:find_by, nil) do
          # fehlendes TournamentCc wird geloggt (Rails.logger.error), kein Exception
          result = nil
          assert_nothing_raised do
            result = RegionCc::TournamentSyncer.call(
              region_cc: @region_cc, client: @client,
              operation: :fix_tournament_structure,
              season_name: "2023/2024"
            )
          end
          # Kein TournamentCc gefunden: Fehler geloggt, Schleife ueber tournaments durchlaufen
          assert_kind_of Array, result
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test 4: Unbekannte Operation wirft ArgumentError
  # ---------------------------------------------------------------------------
  test "raises ArgumentError for unknown operation" do
    assert_raises(ArgumentError) do
      RegionCc::TournamentSyncer.call(
        region_cc: @region_cc, client: @client,
        operation: :invalid_operation
      )
    end
  end

  # ===========================================================================
  # Phase 21-03 T3 / Slice A: TournamentCc Admin-Parameter Scraping
  # ===========================================================================
  # Die folgenden Tests verifizieren die neuen 4 Parser-Branches (Turnierplan,
  # Shot-Clock-Schwellenwert, Ausspielziel, Sätze) und ihre Behavior-Preservation
  # gegenüber den bestehenden Branches.

  # ---------------------------------------------------------------------------
  # Test 5: Parser extrahiert die 4 neuen Felder aus einer synthetischen
  # vollwertig befüllten showMeisterschaft.php-Antwort.
  # ---------------------------------------------------------------------------
  test "sync_tournament_ccs extrahiert shot_clock_minutes, points_to_win, best_of_sets, tournament_plan_cc_id (populated)" do
    list_html = <<~HTML
      <html><body>
        <input name="errMsg" value="">
        <a class="cc_bluelink" href="showMeisterschaft.php?p=20-10-*-2023/2024-*-*-50001--1&amp;">Sample</a>
      </body></html>
    HTML

    detail_html = <<~HTML
      <html><body>
        <tr class="tableContent"><td><table>
          <tr><td>Meisterschaft</td><td></td><td><strong>Synth Cup</strong></td></tr>
          <tr><td>Kurzbezeichner</td><td></td><td>SC</td></tr>
          <tr><td>Disziplin</td><td></td><td>Dreiband (kleines Billard)</td></tr>
          <tr><td>Turnierplan</td><td></td><td><b>Custom Plan A</b></td></tr>
          <tr><td>Shot-Clock-Schwellenwert</td><td></td><td><strong>3 Minuten</strong> <i>(...help...)</i></td></tr>
          <tr><td>Ausspielziel</td><td></td><td><strong>50</strong> <i>(...help...)</i></td></tr>
          <tr><td>Sätze (Best-of-#)</td><td></td><td><b>7</b> <i>(...help...)</i></td></tr>
          <tr><td>Status</td><td></td><td>Veröffentlicht</td></tr>
        </table></td></tr>
      </body></html>
    HTML

    branch_cc = BranchCc.new(cc_id: 10, name: "Karambol")
    branch_cc.define_singleton_method(:id) { 4711 }
    region_cc_stub = RegionCc.new(cc_id: 20)
    region_stub = Region.new
    region_stub.define_singleton_method(:cc_id) { 20 }
    region_stub.define_singleton_method(:region_cc) { region_cc_stub }
    region_cc_stub.define_singleton_method(:branch_ccs) { [branch_cc] }
    season = Season.new(id: 5, name: "2023/2024")

    @client.expect(:post, [OpenStruct.new(message: "OK"), Nokogiri::HTML(list_html)],
      ["showMeisterschaftenList", Hash, Hash])
    @client.expect(:get, [OpenStruct.new(message: "OK"), Nokogiri::HTML(detail_html)],
      ["showMeisterschaft", Hash, Hash])

    discipline = Discipline.new
    discipline.define_singleton_method(:id) { 99 }

    Region.stub(:find_by_shortname, region_stub) do
      Season.stub(:find_by_name, season) do
        Discipline.stub(:find_by_name, discipline) do
          # Inject an empty mirror so the find_or_initialize path triggers an update on a fresh record
          TournamentCc.where(cc_id: 50_001).destroy_all
          TournamentPlanCc.where(name: "Custom Plan A", context: "nbv").destroy_all

          RegionCc::TournamentSyncer.call(
            region_cc: @region_cc, client: @client,
            operation: :sync_tournament_ccs,
            context: "nbv", season_name: "2023/2024",
            update_from_cc: true
          )
        end
      end
    end

    persisted = TournamentCc.find_by(cc_id: 50_001)
    refute_nil persisted, "Expected TournamentCc cc_id=50001 to be persisted"
    assert_equal 3, persisted.shot_clock_minutes,
      "shot_clock_minutes parser failed: got #{persisted.shot_clock_minutes.inspect}"
    assert_equal 50, persisted.points_to_win,
      "points_to_win parser failed"
    assert_equal 7, persisted.best_of_sets,
      "best_of_sets parser failed"
    refute_nil persisted.tournament_plan_cc_id,
      "tournament_plan_cc_id not set"
    plan = TournamentPlanCc.find(persisted.tournament_plan_cc_id)
    assert_equal "Custom Plan A", plan.name
    assert_equal "nbv", plan.context
    # Behavior-preservation: name + shortname stay correct
    assert_equal "Synth Cup", persisted.name
    assert_equal "SC", persisted.shortname

    @client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 6: NBV-Default-Werte (0 Minuten / 0 Ausspielziel / 1 Best-of, leerer Plan)
  # werden korrekt als NULL/1 persistiert (Sentinel-Konvention).
  # ---------------------------------------------------------------------------
  test "sync_tournament_ccs persistiert NBV-Defaults als NULL/NULL/1/NULL (0-Sentinel)" do
    list_html = <<~HTML
      <html><body>
        <input name="errMsg" value="">
        <a class="cc_bluelink" href="showMeisterschaft.php?p=20-10-*-2023/2024-*-*-50002--1&amp;">Sample</a>
      </body></html>
    HTML

    # Mimics the real NBV cc_id=51 fixture: empty/0-default values across all 4 fields.
    detail_html = <<~HTML
      <html><body>
        <tr class="tableContent"><td><table>
          <tr><td>Meisterschaft</td><td></td><td><strong>NDM Default</strong></td></tr>
          <tr><td>Turnierplan</td><td></td><td><b></b></td></tr>
          <tr><td>Shot-Clock-Schwellenwert</td><td></td><td><strong>0 Minuten</strong> <i>(...)</i></td></tr>
          <tr><td>Ausspielziel</td><td></td><td><strong>0</strong> <i>(Null bedeutet keine Ausspielbegrenzung.)</i></td></tr>
          <tr><td>Sätze (Best-of-#)</td><td></td><td><b>1</b> <i>(...)</i></td></tr>
        </table></td></tr>
      </body></html>
    HTML

    branch_cc = BranchCc.new(cc_id: 10, name: "Karambol")
    branch_cc.define_singleton_method(:id) { 4711 }
    region_cc_stub = RegionCc.new(cc_id: 20)
    region_stub = Region.new
    region_stub.define_singleton_method(:cc_id) { 20 }
    region_stub.define_singleton_method(:region_cc) { region_cc_stub }
    region_cc_stub.define_singleton_method(:branch_ccs) { [branch_cc] }
    season = Season.new(id: 5, name: "2023/2024")

    @client.expect(:post, [OpenStruct.new(message: "OK"), Nokogiri::HTML(list_html)],
      ["showMeisterschaftenList", Hash, Hash])
    @client.expect(:get, [OpenStruct.new(message: "OK"), Nokogiri::HTML(detail_html)],
      ["showMeisterschaft", Hash, Hash])

    Region.stub(:find_by_shortname, region_stub) do
      Season.stub(:find_by_name, season) do
        TournamentCc.where(cc_id: 50_002).destroy_all

        RegionCc::TournamentSyncer.call(
          region_cc: @region_cc, client: @client,
          operation: :sync_tournament_ccs,
          context: "nbv", season_name: "2023/2024",
          update_from_cc: true
        )
      end
    end

    persisted = TournamentCc.find_by(cc_id: 50_002)
    refute_nil persisted
    assert_nil persisted.shot_clock_minutes, "0 Minuten must persist as NULL (sentinel)"
    assert_nil persisted.points_to_win, "0 Ausspielziel must persist as NULL (ClubCloud-help: 'Null bedeutet keine Begrenzung')"
    assert_equal 1, persisted.best_of_sets, "best_of_sets=1 ist legitimer Default-Wert, NICHT NULL"
    assert_nil persisted.tournament_plan_cc_id, "empty <b></b> Plan-Name → KEIN TournamentPlanCc-Record"

    @client.verify
  end

  # ---------------------------------------------------------------------------
  # Test 7: Idempotenz — zweimaliger Sync mit gleichem TurnierPlan-Namen
  # erzeugt NUR EIN TournamentPlanCc-Record.
  # ---------------------------------------------------------------------------
  test "sync_tournament_ccs ist idempotent für TournamentPlanCc (find_or_create_by)" do
    list_html = <<~HTML
      <html><body>
        <input name="errMsg" value="">
        <a class="cc_bluelink" href="showMeisterschaft.php?p=20-10-*-2023/2024-*-*-50003--1&amp;">Sample</a>
      </body></html>
    HTML
    detail_html = <<~HTML
      <html><body>
        <tr class="tableContent"><td><table>
          <tr><td>Meisterschaft</td><td></td><td><strong>Idem Test</strong></td></tr>
          <tr><td>Turnierplan</td><td></td><td><b>Shared Plan</b></td></tr>
        </table></td></tr>
      </body></html>
    HTML

    branch_cc = BranchCc.new(cc_id: 10, name: "Karambol")
    branch_cc.define_singleton_method(:id) { 4711 }
    region_cc_stub = RegionCc.new(cc_id: 20)
    region_stub = Region.new
    region_stub.define_singleton_method(:cc_id) { 20 }
    region_stub.define_singleton_method(:region_cc) { region_cc_stub }
    region_cc_stub.define_singleton_method(:branch_ccs) { [branch_cc] }
    season = Season.new(id: 5, name: "2023/2024")

    # 2 sync runs, same plan name
    2.times do
      @client.expect(:post, [OpenStruct.new(message: "OK"), Nokogiri::HTML(list_html)],
        ["showMeisterschaftenList", Hash, Hash])
      @client.expect(:get, [OpenStruct.new(message: "OK"), Nokogiri::HTML(detail_html)],
        ["showMeisterschaft", Hash, Hash])
    end

    Region.stub(:find_by_shortname, region_stub) do
      Season.stub(:find_by_name, season) do
        TournamentCc.where(cc_id: 50_003).destroy_all
        TournamentPlanCc.where(name: "Shared Plan", context: "nbv").destroy_all

        2.times do
          RegionCc::TournamentSyncer.call(
            region_cc: @region_cc, client: @client,
            operation: :sync_tournament_ccs,
            context: "nbv", season_name: "2023/2024",
            update_from_cc: true
          )
        end
      end
    end

    plans = TournamentPlanCc.where(name: "Shared Plan", context: "nbv")
    assert_equal 1, plans.count, "idempotency-Verletzung: TournamentPlanCc.find_or_create_by erzeugte #{plans.count} Records statt 1"
    @client.verify
  end
end
