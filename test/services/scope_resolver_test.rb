# frozen_string_literal: true

require "test_helper"

# Deckt die Server-Kontext-Region des Scope-Bands ab.
#
# HINTERGRUND: `context` ist in den Szenario-Configs uneinheitlich geschrieben — "nbv"/"tbv" klein,
# "NBV"/"TBV"/"API" gross. Ein exaktes `find_by(shortname:)` traf die kleingeschriebenen nie und
# fiel still auf den pragmatischen NBV-Default zurueck. Auf nbv.carambus.de war das unsichtbar
# (Fallback == richtige Region), auf tbv.carambus.de zeigte das Band NBV statt TBV.
class ScopeResolverTest < ActiveSupport::TestCase
  test "kleingeschriebener Server-Kontext loest die Region auf" do
    with_context("bbv") do
      assert_equal regions(:bbv).id, ScopeResolver.new.region_id
    end
  end

  test "grossgeschriebener Server-Kontext loest dieselbe Region auf" do
    with_context("BBV") do
      assert_equal regions(:bbv).id, ScopeResolver.new.region_id
    end
  end

  test "unbekannter Kontext faellt auf den Default zurueck statt zu scheitern" do
    with_context("GIBTESNICHT") do
      assert_equal regions(:nbv).id, ScopeResolver.new.region_id
    end
  end

  test "Session schlaegt den Server-Kontext" do
    with_context("bbv") do
      resolver = ScopeResolver.new(session_scope: {"region" => regions(:nbv).id.to_s})
      assert_equal regions(:nbv).id, resolver.region_id
    end
  end

  private

  # Die ganze Config ersetzen (Muster aus prepare_tournament_test.rb): `Carambus.config` traegt in
  # der Testumgebung gar keinen `context`-Key, ein `stub(:context, …)` darauf schlaegt deshalb fehl.
  # ScopeResolver liest ausschliesslich `context` — ein minimaler OpenStruct genuegt.
  def with_context(value, &block)
    Carambus.stub(:config, OpenStruct.new(context: value), &block)
  end
end
