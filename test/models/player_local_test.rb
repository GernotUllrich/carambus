# frozen_string_literal: true

require "test_helper"

# Lokale Kontaktdaten zu einem Spieler.
#
# ⚠️ Der Kern der Anforderung (Betreiber 2026-08-30): diese Daten sollen BEWUSST nicht auf der
# Authority stehen. Das ist keine Frage der Disziplin, sondern der Struktur — die letzten Tests
# hier halten sie fest.
class PlayerLocalTest < ActiveSupport::TestCase
  setup do
    # ⚠️ PFLICHT: `PlayerLocal` speichert nur auf einem lokalen Server; ohne gesetztes
    # `carambus_api_url` gilt dieser Lauf als Authority und jedes Schreiben wird abgewiesen.
    # Genau das ist die gewuenschte Wirkung — fuer die uebrigen Tests wird die Rolle gestellt.
    @original_config = Carambus.config
    Carambus.config = OpenStruct.new(@original_config.to_h.merge(carambus_api_url: "http://localhost:3131"))
    @player = players(:nbv_ullrich)
  end

  teardown do
    Carambus.config = @original_config
  end

  def kontakt!(**attrs)
    PlayerLocal.create!({player: @player, email: "max@example.com"}.merge(attrs))
  end

  test "eine Adresse laesst sich am Spieler fuehren" do
    kontakt!
    assert_equal "max@example.com", @player.reload.player_local.email
  end

  test "je Spieler nur ein Datensatz" do
    kontakt!
    zweiter = PlayerLocal.new(player: @player, email: "zweit@example.com")

    refute zweiter.valid?, "der Unique-Index haette sonst als 500 zugeschlagen"
    assert_includes zweiter.errors.attribute_names, :player_id
  end

  # Ohne die Normalisierung waeren "Max@Example.COM" und "max@example.com" zwei Adressen.
  test "die Adresse wird normalisiert" do
    kontakt = kontakt!(email: "  Max@Example.COM  ")
    assert_equal "max@example.com", kontakt.email
  end

  # Ein leeres Formularfeld liefert "", nicht nil — ohne Normalisierung liesse sich eine einmal
  # eingetragene Adresse nicht wieder loeschen.
  test "ein leeres Feld loescht die Adresse, statt ungueltig zu sein" do
    kontakt = kontakt!
    kontakt.update!(email: "")

    assert_nil kontakt.reload.email
  end

  test "offensichtlicher Unsinn wird abgewiesen" do
    kontakt = PlayerLocal.new(player: @player, email: "kein-at-zeichen")
    refute kontakt.valid?
    assert_includes kontakt.errors.attribute_names, :email
  end

  # --- Einwilligung -----------------------------------------------------------------------

  test "ohne Einwilligung nicht anschreibbar" do
    kontakt = kontakt!
    refute kontakt.contactable?
    assert_empty PlayerLocal.contactable
  end

  test "mit Einwilligung anschreibbar" do
    kontakt = kontakt!(consent_given_at: 1.day.ago)
    assert kontakt.contactable?
    assert_includes PlayerLocal.contactable, kontakt
  end

  test "nach Widerruf nicht mehr anschreibbar" do
    kontakt = kontakt!(consent_given_at: 2.days.ago, consent_revoked_at: 1.day.ago)

    refute kontakt.contactable?
    assert_empty PlayerLocal.contactable
    assert kontakt.revoked?
    assert_equal "max@example.com", kontakt.email,
      "der Widerruf loescht die Adresse nicht — er haelt fest, dass nicht angeschrieben wird"
  end

  test "ohne Adresse nicht anschreibbar, auch mit Einwilligung" do
    kontakt = kontakt!(email: nil, consent_given_at: 1.day.ago)
    refute kontakt.contactable?
    assert_empty PlayerLocal.contactable
  end

  # Scope und Praedikat duerfen nicht auseinanderlaufen — sonst schreibt eine Empfaengerliste
  # jemanden an, den `contactable?` ausschliesst.
  test "Scope und Praedikat sind sich einig" do
    faelle = [
      {email: "a@example.com"},
      {email: "b@example.com", consent_given_at: 1.day.ago},
      {email: "c@example.com", consent_given_at: 2.days.ago, consent_revoked_at: 1.day.ago},
      {email: nil, consent_given_at: 1.day.ago}
    ]
    spieler = [players(:nbv_ullrich), players(:nbv_andresen), players(:nbv_hansen), players(:jaspers)]

    kontakte = faelle.each_with_index.map { |attrs, i| PlayerLocal.create!(attrs.merge(player: spieler[i])) }
    per_scope = PlayerLocal.contactable.to_a

    kontakte.each do |k|
      assert_equal k.contactable?, per_scope.include?(k),
        "Scope und Praedikat widersprechen sich fuer #{k.email.inspect}"
    end
  end

  # --- Die eigentliche Zusicherung: bleibt lokal --------------------------------------------

  # ⚠️ Das ist der Grund fuer die eigene Tabelle. Auf der Authority wird jedes Schreiben
  # abgewiesen — die Tabelle existiert dort nach der Migration zwar, kann aber nicht befuellt
  # werden. Der Guard haengt allein an der Rolle des Servers, NICHT an der ID: der
  # Sequence-Startwert steht nicht in schema.rb und ueberlebt kein `db:schema:load`.
  test "auf der Authority laesst sich kein Kontakt anlegen" do
    Carambus.config = OpenStruct.new(@original_config.to_h.merge(carambus_api_url: nil))
    refute ApplicationRecord.local_server?, "Vorbedingung: dieser Lauf gilt als Authority"

    assert_no_difference("PlayerLocal.count") do
      kontakt = PlayerLocal.create(player: @player, email: "darf-nicht@example.com")
      refute kontakt.persisted?
      assert_includes kontakt.errors.attribute_names, :base
    end
  end

  # ⚠️ Die zweite Zusicherung: geloescht heisst geloescht. `ApiProtector` schaltet auf lokalen
  # Servern `has_paper_trail` ein — eine entfernte Adresse bliebe dann in `versions` stehen.
  # Deshalb traegt dieses Modell den Concern NICHT.
  test "eine geloeschte Adresse hinterlaesst keine Version" do
    kontakt = kontakt!
    refute kontakt.respond_to?(:versions),
      "mit PaperTrail waere die Adresse nach dem Loeschen weiter lesbar"

    id = kontakt.id
    kontakt.destroy
    assert_equal 0, Version.where(item_type: "PlayerLocal", item_id: id).count
  end

  # Die Adresse ist personenbezogen — sie ohne Spieler zurueckzulassen waere ein Datensatz
  # ohne Zweck.
  test "mit dem Spieler verschwindet die Adresse" do
    kontakt!
    assert_difference("PlayerLocal.count", -1) do
      @player.destroy
    end
  end
end
