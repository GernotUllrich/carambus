# frozen_string_literal: true

require "test_helper"
require "digest"
require "tmpdir"
require Rails.root.join("lib", "burned_secret_guard")

# Plan 21-02: Die Baum-Wache haelt verbrannte Geheimnisse aus dem Repo — im pre-commit
# ueber die gestagten Dateien, in CI ueber den ganzen getrackten Baum.
#
# Die Gegenprobe ist hier kein nachtraeglicher Schritt, sondern der Test selbst: jeder
# Rot-Fall hat seinen Gruen-Partner. Ein Wachtest, der nur den sauberen Fall prueft,
# bliebe auch dann gruen, wenn die Wache gar nichts taete.
#
# Gearbeitet wird durchweg mit einem FREI ERFUNDENEN Testwert — kein echtes Geheimnis
# im Test, und keine Abhaengigkeit von der gepflegten lib/credential_denylist.yml.
class BurnedSecretGuardTest < ActiveSupport::TestCase
  # Frei erfunden. Erfuellt TOKEN_RE (nur [A-Za-z0-9+/=_-], >= 8 Zeichen).
  TESTWERT = "Tw7x_Kq2ZvB4nR8s"
  HINT = "testwert.frei-erfunden (nur fuer diesen Test)"

  def denylist
    {Digest::SHA256.hexdigest(TESTWERT) => HINT}
  end

  # Fuehrt die Wache aus und liefert [sauber?, Ausgabe].
  def run_guard(paths, list = denylist)
    out = StringIO.new
    ok = BurnedSecretGuard.check(paths, denylist: list, out: out)
    [ok, out.string]
  end

  def with_file(content, name: "probe.txt", binary: false)
    Dir.mktmpdir("burned-secret-guard") do |dir|
      path = File.join(dir, name)
      binary ? File.binwrite(path, content) : File.write(path, content)
      yield path
    end
  end

  test "schlaegt an, wenn ein Sperrlisten-Wert in der Datei steht" do
    with_file("harmlos\ndatabase_password: #{TESTWERT}\nnoch was\n") do |path|
      ok, out = run_guard([path])

      assert_not ok, "Die Wache haette anschlagen muessen"
      assert_includes out, path
      assert_includes out, ":2", "Die Zeilennummer des Treffers fehlt"
      assert_includes out, HINT
    end
  end

  # Gegenprobe zum Test darueber: derselbe Aufbau ohne den Wert muss gruen sein.
  # Ohne diesen Fall wuerde eine Wache, die IMMER rot ist, den Test oben bestehen.
  test "ist gruen, wenn derselbe Inhalt den Wert nicht mehr enthaelt" do
    with_file("harmlos\ndatabase_password: ENTFERNT\nnoch was\n") do |path|
      ok, out = run_guard([path])

      assert ok, "Die Wache haette gruen sein muessen, war: #{out}"
      assert_includes out, "0 Treffer"
    end
  end

  test "gibt den gefundenen Wert nirgends aus" do
    with_file("secret: #{TESTWERT}\n") do |path|
      _ok, out = run_guard([path])

      assert_not_includes out, TESTWERT
      # Auch nicht gekuerzt: kein Praefix ab 8 Zeichen darf durchrutschen.
      assert_not_includes out, TESTWERT[0, 8]
    end
  end

  test "ueberspringt binaere Dateien" do
    with_file("\0\0#{TESTWERT}\0\0", name: "probe.bin", binary: true) do |path|
      ok, = run_guard([path])

      assert ok, "Binaerdateien werden bewusst nicht gescannt"
    end
  end

  test "ueberspringt Dateien ueber der Groessengrenze" do
    fueller = "x" * (BurnedSecretGuard::MAX_BYTES + 1)
    with_file("#{fueller}\n#{TESTWERT}\n", name: "gross.txt") do |path|
      assert_operator File.size(path), :>, BurnedSecretGuard::MAX_BYTES

      ok, = run_guard([path])

      assert ok, "Dateien ueber MAX_BYTES werden bewusst nicht gescannt"
    end
  end

  test "findet einen Wert, der nur ein Teil einer laengeren Zeile ist" do
    with_file(%(url = "postgres://www_data:#{TESTWERT}@localhost/db"\n)) do |path|
      ok, out = run_guard([path])

      assert_not ok, "Der Tokenizer muss den Wert auch zwischen Trennzeichen finden"
      assert_includes out, HINT
    end
  end

  test "die echte Sperrliste ist lesbar und enthaelt den www_data-Fingerprint" do
    list = BurnedSecretGuard.load_denylist

    assert_operator list.size, :>=, 29
    assert list.key?("44b18fa9c3ce6775633dc65e16f41123b698bef83d58ecbcc0a95a642cf69dce"),
      "Der www_data-Fingerprint fehlt — ein build_credential_denylist-Lauf hat ihn vermutlich entfernt"
  end

  # Bewusst mit der ECHTEN Sperrliste, nicht mit der des Tests: diese Datei traegt
  # TESTWERT im Klartext und ist getrackt — mit der Test-Sperrliste wuerde der Scan
  # sie selbst finden und immer rot sein. (Genau so passiert am 2026-09-20: der
  # Einzellauf war gruen, solange die Datei noch untracked war, die Suite nach dem
  # Commit rot. Der Befund war echt, das Kriterium falsch.)
  test "der getrackte Baum ist gegen die echte Sperrliste sauber" do
    ok, out = run_guard([], BurnedSecretGuard.load_denylist)

    assert ok, "Verbranntes Geheimnis im getrackten Baum:\n#{out}"
  end
end
