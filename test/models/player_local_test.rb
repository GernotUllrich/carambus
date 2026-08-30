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
  # ---------------------------------------------------------------------------------------
  # PIN / Anmeldung im Spielerkontext (Plan 02.1-01)
  # ---------------------------------------------------------------------------------------

  test "der PIN ist optional — Kontaktdaten funktionieren ohne ihn" do
    k = kontakt!
    assert_nil k.pin_digest
    refute k.pin_set?
  end

  test "der PIN wird gehasht abgelegt, niemals im Klartext" do
    k = kontakt!(pin: "4711")

    assert k.pin_digest.present?
    refute_includes k.pin_digest, "4711"
    assert k.pin_digest.start_with?("$2a$", "$2b$", "$2y$"), "kein bcrypt-Hash: #{k.pin_digest}"
    # Die Spalte `pin` gibt es gar nicht — nur `pin_digest`.
    refute_includes PlayerLocal.column_names, "pin"
  end

  test "vier bis acht Ziffern sind erlaubt" do
    %w[4711 47110 471104 4711047 47110471].each do |pin|
      k = PlayerLocal.new(player: @player, pin: pin)
      k.valid?
      assert_empty k.errors[:pin], "#{pin} haette gelten muessen"
    end
  end

  test "zu kurz, zu lang oder nicht numerisch wird abgewiesen" do
    %w[471 471104711 abcd 47a1].each do |pin|
      k = PlayerLocal.new(player: @player, pin: pin)
      refute k.valid?, "#{pin} haette abgewiesen werden muessen"
      refute_empty k.errors[:pin]
    end
  end

  test "triviale PINs werden abgewiesen" do
    k = PlayerLocal.new(player: @player, pin: "1234")

    refute k.valid?
    refute_empty k.errors[:pin]
  end

  test "ein leeres Feld loescht den vorhandenen PIN NICHT" do
    k = kontakt!(pin: "4711")
    vorher = k.pin_digest

    # Genau das passiert beim Speichern der Adresse: Administrate schickt `pin` leer mit.
    k.update!(email: "neu@example.com", pin: "")

    assert_equal vorher, k.reload.pin_digest, "das leere Formularfeld hat den PIN geloescht"
  end

  test "clear_pin! entfernt den PIN und den Sperrzustand" do
    k = kontakt!(pin: "4711")
    k.update!(failed_pin_attempts: 3)

    k.clear_pin!

    refute k.pin_set?
    assert_equal 0, k.failed_pin_attempts
    assert_nil k.pin_locked_until
  end

  test "richtiger PIN meldet an und setzt den Zaehler zurueck" do
    k = kontakt!(pin: "4711")
    k.update!(failed_pin_attempts: 3)

    assert k.verify_pin("4711")
    assert_equal 0, k.reload.failed_pin_attempts
  end

  test "falscher PIN zaehlt hoch, sperrt aber noch nicht" do
    k = kontakt!(pin: "4711")

    4.times { refute k.verify_pin("0815") }

    assert_equal 4, k.reload.failed_pin_attempts
    refute k.pin_locked?, "vor dem fuenften Fehlversuch darf nicht gesperrt sein"
  end

  test "der fuenfte Fehlversuch sperrt eine Minute" do
    k = kontakt!(pin: "4711")

    5.times { k.verify_pin("0815") }

    assert k.reload.pin_locked?
    assert_in_delta 60, k.pin_lock_remaining, 2
  end

  test "jeder weitere Fehlversuch verdoppelt die Wartezeit" do
    k = kontakt!(pin: "4711")
    5.times { k.verify_pin("0815") }

    # Waehrend der Sperre wird gar nicht geprueft — also die Sperre ablaufen lassen.
    travel_to(k.pin_locked_until + 1.second) do
      refute k.verify_pin("0815")
      assert_in_delta 120, k.reload.pin_lock_remaining, 2
    end
  end

  test "die Wartezeit ist bei einer Stunde gedeckelt" do
    k = kontakt!(pin: "4711")
    k.update!(failed_pin_attempts: 40)

    k.register_failed_pin_attempt!

    assert_operator k.reload.pin_lock_remaining, :<=, 3600
    assert_operator k.pin_lock_remaining, :>, 3500
  end

  test "waehrend der Sperre wird auch der RICHTIGE PIN abgewiesen" do
    k = kontakt!(pin: "4711")
    5.times { k.verify_pin("0815") }

    refute k.verify_pin("4711"), "sonst liesse sich waehrend der Sperre weiter durchprobieren"
  end

  test "nach Ablauf der Sperre gilt der richtige PIN wieder" do
    k = kontakt!(pin: "4711")
    5.times { k.verify_pin("0815") }

    travel_to(k.pin_locked_until + 1.second) do
      assert k.verify_pin("4711")
      assert_equal 0, k.reload.failed_pin_attempts
    end
  end

  test "ohne gesetzten PIN meldet niemand an" do
    k = kontakt!

    refute k.verify_pin("4711")
    refute k.verify_pin("")
  end

  test "auf der Authority entsteht kein PIN" do
    # Rolle auf Authority stellen: kein carambus_api_url.
    Carambus.config = OpenStruct.new(@original_config.to_h.merge(carambus_api_url: nil))

    k = PlayerLocal.new(player: @player, pin: "4711")

    refute k.save, "der Guard nur_auf_lokalem_server haette greifen muessen"
    assert_nil PlayerLocal.find_by(player_id: @player.id)
  end

  test "jeder Fehlversuch wird protokolliert — ohne den eingegebenen PIN" do
    k = kontakt!(pin: "4711")
    mitschrift = StringIO.new
    vorher = Rails.logger
    Rails.logger = Logger.new(mitschrift)

    begin
      k.verify_pin("0815")
    ensure
      Rails.logger = vorher
    end

    zeile = mitschrift.string
    assert_includes zeile, "player_id=#{@player.id}"
    assert_includes zeile, "versuche=1"
    refute_includes zeile, "0815", "der eingegebene PIN darf NIEMALS im Protokoll stehen"
  end
  # ---------------------------------------------------------------------------------------
  # Einladung per Einmal-Link (Plan 02.2-01)
  # ---------------------------------------------------------------------------------------

  test "der Token loest den richtigen Datensatz auf" do
    k = kontakt!(email: "max@example.com", consent_given_at: Time.current)

    assert_equal k, PlayerLocal.find_by_token_for(:pin_setup, k.generate_token_for(:pin_setup))
  end

  # ⚠️ DAS ist die Einmaligkeit — sie kommt aus der Bindung an `pin_digest`, nicht aus einem
  # Flag, das jemand zuruecksetzen muesste.
  test "der Token wird ungueltig, sobald ein PIN gesetzt wird" do
    k = kontakt!(email: "max@example.com", consent_given_at: Time.current)
    t = k.generate_token_for(:pin_setup)

    k.update!(pin: "4711")

    assert_nil PlayerLocal.find_by_token_for(:pin_setup, t),
      "der Link muss nach dem Setzen tot sein"
  end

  test "der Token laeuft ab" do
    k = kontakt!(email: "max@example.com", consent_given_at: Time.current)
    t = k.generate_token_for(:pin_setup)

    travel_to(PlayerLocal::PIN_SETUP_TOKEN_VALIDITY.from_now + 1.hour) do
      assert_nil PlayerLocal.find_by_token_for(:pin_setup, t)
    end
  end

  test "ein erfundener Token loest nichts auf" do
    assert_nil PlayerLocal.find_by_token_for(:pin_setup, "voellig-erfunden")
  end

  # ---------------------------------------------------------------------------------------
  # Die Einladungs-Mail
  # ---------------------------------------------------------------------------------------

  test "die Einladung geht an die hinterlegte Adresse" do
    k = kontakt!(email: "max@example.com", consent_given_at: Time.current)

    mail = PlayerLocalMailer.pin_setup(k)

    assert_equal ["max@example.com"], mail.to
    assert_equal I18n.t("player_local_mailer.pin_setup.subject"), mail.subject
  end

  # ⚠️ Der Kern der Entscheidung „Einmal-Link statt PIN in der Mail".
  test "in der Mail steht KEIN PIN und KEIN Digest" do
    k = kontakt!(email: "max@example.com", consent_given_at: Time.current, pin: "4711")

    rumpf = PlayerLocalMailer.pin_setup(k).body.encoded

    refute_includes rumpf, "4711", "ein PIN darf niemals in der Mail landen"
    refute_includes rumpf, k.pin_digest.to_s, "der Digest erst recht nicht"
  end

  test "die Mail traegt einen absoluten Link" do
    k = kontakt!(email: "max@example.com", consent_given_at: Time.current)

    rumpf = PlayerLocalMailer.pin_setup(k).body.encoded

    assert_match(%r{https?://[^/]+/pin_setup/}, rumpf,
      "ein relativer Pfad waere in einer Mail nutzlos")
  end

  test "die Mail hat einen Text- UND einen HTML-Teil" do
    k = kontakt!(email: "max@example.com", consent_given_at: Time.current)

    mail = PlayerLocalMailer.pin_setup(k)

    # ⚠️ Reine HTML-Mails landen haeufiger im Spam — und dies ist die allererste Mail dieser
    # Anwendung ueberhaupt.
    assert mail.multipart?, "die Mail muss Text und HTML tragen"
    assert_equal %w[text/plain text/html], mail.parts.map(&:mime_type).sort.reverse
  end

  # ⚠️ Der Guard steht im Mailer selbst, nicht nur beim Aufrufer.
  test "ohne gueltige Einwilligung geht KEINE Mail raus" do
    ohne_einwilligung = kontakt!(email: "max@example.com")
    assert_nil PlayerLocalMailer.pin_setup(ohne_einwilligung).message_id

    ohne_einwilligung.update!(consent_given_at: Time.current)
    ohne_einwilligung.revoke_consent!
    assert_nil PlayerLocalMailer.pin_setup(ohne_einwilligung.reload).message_id
  end

  test "ohne Adresse geht KEINE Mail raus" do
    ohne_adresse = kontakt!(email: nil, consent_given_at: Time.current)

    assert_nil PlayerLocalMailer.pin_setup(ohne_adresse).message_id
  end
end
