# frozen_string_literal: true

require "test_helper"

module NuLiga
  class ClientTest < ActiveSupport::TestCase
    test "championship builds the canonical NuLiga string from a full season name" do
      assert_equal "BBV Pool 25/26",
        Client.championship(federation: "BBV", branch: "Pool", season_name: "2025/2026")
      assert_equal "BBV Karambol 25/26",
        Client.championship(federation: "BBV", branch: "Karambol", season_name: "2025/2026")
    end

    test "championship tolerates an already-short season name" do
      assert_equal "BBV Snooker 25/26",
        Client.championship(federation: "BBV", branch: "Snooker", season_name: "25/26")
    end

    test "get_html decodes ISO-8859-1 to UTF-8 and returns a String" do
      VCR.use_cassette("nuliga/leaguePage_pool_2025-26") do
        html = Client.new.get_html("leaguePage", championship: "BBV Pool 25/26")
        assert_kind_of String, html
        assert_equal Encoding::UTF_8, html.encoding
        # „Übergeordnete Spielklassen" — Umlaut nur bei korrekter Dekodierung vorhanden
        assert_includes html, "Übergeordnete"
        # WebObjects-Artefakt bereinigt
        refute_includes html, "//--"
      end
    end

    test "get_doc returns a parseable Nokogiri fragment" do
      VCR.use_cassette("nuliga/leaguePage_pool_2025-26") do
        doc = Client.new.get_doc("leaguePage", championship: "BBV Pool 25/26")
        assert_kind_of Nokogiri::XML::Node, doc
        assert_operator doc.css('a[href*="groupPage"]').size, :>, 0
      end
    end

    test "get_html raises a clear error on a non-2xx response" do
      stub_request(:get, /bbv-billard\.liga\.nu/).to_return(status: 500, body: "err")
      err = assert_raises(RuntimeError) { Client.new.get_html("leaguePage", championship: "x") }
      assert_match(/HTTP 500/, err.message)
    end
  end
end
