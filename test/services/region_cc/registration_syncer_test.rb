# frozen_string_literal: true

require "test_helper"

# Unit tests für RegionCc::RegistrationSyncer post Plan 23-01 T2.
# Syncer schreibt jetzt TournamentCc.meldeliste_*-Felder direkt, nicht mehr
# RegistrationListCc. Tests testen die Match-Logik (context+name → TCc) und
# das HTML-Parsing der V2-UI-Tabelle.
class RegionCc::RegistrationSyncerTest < ActiveSupport::TestCase
  setup do
    @region_cc = RegionCc.new(cc_id: 20, shortname: "NBV")
    @client = Minitest::Mock.new
    @season = Season.new(id: 5, name: "2025/2026")
    @branch_cc = BranchCc.new(cc_id: 10, id: 1)
  end

  test "raises ArgumentError for unknown operation" do
    assert_raises(ArgumentError) do
      RegionCc::RegistrationSyncer.call(
        region_cc: @region_cc, client: @client,
        operation: :unknown_operation
      )
    end
  end

  test "updates matching TournamentCc with meldeliste_cc_id + deadline + qualifying_date" do
    html = build_meldelisten_html([
      {cc_id: 777, name: "Test Meldeliste 23-01", deadline: "15.06.2025", qualifying_date: "01.01.2025", status: "Gemeldet"}
    ])

    @client.expect(:post, [OpenStruct.new(message: "OK"), Nokogiri::HTML(html)],
      ["showMeldelistenList", Hash, Hash])

    tcc_attrs = nil
    tcc_stub = Object.new
    tcc_stub.define_singleton_method(:update_columns) { |attrs| tcc_attrs = attrs }

    TournamentCc.stub(:where, ->(*) {
      relation = Object.new
      relation.define_singleton_method(:where) { |*| relation }
      relation.define_singleton_method(:none?) { false }
      relation.define_singleton_method(:find_each) { |&block| block.call(tcc_stub) }
      relation
    }) do
      assert_nothing_raised do
        RegionCc::RegistrationSyncer.call(
          region_cc: @region_cc, client: @client,
          operation: :sync_registration_list_ccs_detail,
          season: @season, branch_cc: @branch_cc,
          context: "nbv"
        )
      end
    end

    assert_not_nil tcc_attrs, "TournamentCc.update_columns muss aufgerufen worden sein"
    assert_equal 777, tcc_attrs[:meldeliste_cc_id]
    assert_equal Date.new(2025, 6, 15), tcc_attrs[:meldeliste_deadline]
    assert_equal Date.new(2025, 1, 1), tcc_attrs[:meldeliste_qualifying_date]
    @client.verify
  end

  test "skips rows without matching TournamentCc (no crash)" do
    html = build_meldelisten_html([
      {cc_id: 888, name: "Orphan Meldeliste ohne TCc", deadline: "01.07.2025", qualifying_date: "01.01.2025", status: "Gemeldet"}
    ])

    @client.expect(:post, [OpenStruct.new(message: "OK"), Nokogiri::HTML(html)],
      ["showMeldelistenList", Hash, Hash])

    TournamentCc.stub(:where, ->(*) {
      relation = Object.new
      relation.define_singleton_method(:where) { |*| relation }
      relation.define_singleton_method(:none?) { true }
      relation.define_singleton_method(:find_each) { |&block| }
      relation
    }) do
      assert_nothing_raised do
        RegionCc::RegistrationSyncer.call(
          region_cc: @region_cc, client: @client,
          operation: :sync_registration_list_ccs_detail,
          season: @season, branch_cc: @branch_cc,
          context: "nbv"
        )
      end
    end

    @client.verify
  end

  private

  # Baut V2-UI-konformes HTML: <table> mit >5 <tr> (extract_meldeliste_rows
  # nimmt nur Tabellen mit `tr.length > 5`). Pro Meldeliste-Row 8 Cells:
  # [Laufnr | Name+Link | Disziplin | Deadline | Kategorie | QualifyingDate | Status | Dashboard]
  # Link-Pattern: ?p=<fed>|<branch>|<disz>|<kat>|<season>|<cc_id>&
  def build_meldelisten_html(rows)
    body_rows = rows.map.with_index(1) do |r, i|
      <<~ROW
        <tr>
          <td>#{i}</td>
          <td><a class="cc_bluelink" href="showMeldeliste.php?p=20|10|*|*|2025/2026|#{r[:cc_id]}&">#{r[:name]}</a></td>
          <td>Karambol</td>
          <td>#{r[:deadline]}</td>
          <td>Senioren (50-99)</td>
          <td>#{r[:qualifying_date]}</td>
          <td>#{r[:status]}</td>
          <td>icon</td>
        </tr>
      ROW
    end.join

    # Mindestens 6 Rows (1 Header + 5 Daten); padding mit Dummy-Rows wenn nötig.
    padding_needed = [6 - (rows.size + 1), 0].max
    padding = ("<tr><td>dummy</td>" * 8 + "</tr>") * padding_needed

    <<~HTML
      <html><body>
        <table>
          <tr><th>Header</th></tr>
          #{body_rows}
          #{padding}
        </table>
      </body></html>
    HTML
  end
end
