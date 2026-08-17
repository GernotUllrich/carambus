# frozen_string_literal: true

require "test_helper"

# Phase 38-01: `InternationalSource` war das einzige replizierte Modell, dessen
# update-Versionen kein `object_changes` trugen (576 von 60 238 auf der Authority,
# ~81/Tag). Für sie gibt es beim Apply nichts zu mergen — die Records hingen auf
# den Regional-Servern systematisch eine Revision hinterher.
#
# Ursache (aus der Gem-Quelle belegt, paper_trail 15.2.0
# `lib/paper_trail/events/update.rb`):
#
#   # `touch` cannot record `object_changes` because rails' `touch` does not
#   # perform dirty-tracking.
#   def record_object_changes? = !@is_touch && super
#
# `mark_scraped!` nutzte `touch(:last_scraped_at)` — der einzige `touch(:spalte)`
# appweit, weshalb kein anderes der 49 replizierten Modelle betroffen war.
# Die Version entstand trotzdem: `Events::Update#changed_notably?` liefert für
# touch `true`, und das `unless`-Gate aus LocalProtector greift nicht, weil
# `saved_changes` von `touch` nicht aktualisiert wird (Rails-Issue #33429).
class InternationalSourceTest < ActiveSupport::TestCase
  def versions_for(source)
    Version.where(item_type: "InternationalSource", item_id: source.id)
  end

  test "mark_scraped! erzeugt gar keine Version mehr" do
    skip_unless_api_server
    source = international_sources(:umb_source)

    assert_no_difference -> { versions_for(source).count } do
      source.mark_scraped!
    end
  end

  # Die Gegenprobe zum Fix: OHNE die Unterdrückung entstand hier eine Version,
  # und zwar eine inhaltsleere (`object_changes` nil) — genau der Defekt, der die
  # Regional-Server eine Revision hinterherhinken liess.
  test "ohne die Unterdrueckung entstuende eine Version ohne object_changes" do
    skip_unless_api_server
    source = international_sources(:umb_source)

    assert_difference -> { versions_for(source).count }, 1 do
      source.touch(:last_scraped_at)
    end

    version = versions_for(source).order(:id).last
    assert_equal "update", version.event
    assert_nil version.object_changes,
      "PaperTrail schreibt auf dem touch-Pfad kein object_changes (Rails-Issue #33429)"
  end

  # Echte Datenänderungen müssen weiterhin vollständig repliziert werden — die
  # 1 873 gesunden `metadata`-Versionen sind vom Fix nicht betroffen.
  test "eine metadata-Aenderung erzeugt weiterhin eine Version MIT object_changes" do
    skip_unless_api_server
    source = international_sources(:umb_source)

    assert_difference -> { versions_for(source).count }, 1 do
      source.update!(metadata: {"channels" => %w[a b]})
    end

    version = versions_for(source).order(:id).last
    assert_not_nil version.object_changes
    assert_includes YAML.unsafe_load(version.object_changes).keys, "metadata"
  end

  test "mark_scraped! schreibt last_scraped_at" do
    skip_unless_api_server
    source = international_sources(:umb_source)

    freshly = Time.current
    source.mark_scraped!

    assert_operator source.reload.last_scraped_at, :>=, freshly,
      "mark_scraped! muss den Betriebsstempel weiterhin setzen"
  end

  # Schutz für das `unless`-Gate aus LocalProtector (Scrape-Hygiene, Phase 19):
  # reine Zeitstempel-Änderungen dürfen KEINE Version erzeugen. Wer das Gate beim
  # Reparieren beschädigt, öffnet die Schleuse für Versionsfluten — und das fällt
  # erst in Produktion auf.
  test "eine reine updated_at-Aenderung erzeugt weiterhin keine Version" do
    skip_unless_api_server
    source = international_sources(:umb_source)

    assert_no_difference -> { versions_for(source).count } do
      source.update!(updated_at: Time.current)
    end
  end
end
