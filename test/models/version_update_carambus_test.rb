# frozen_string_literal: true

require "test_helper"

# Plan 21-06 (F1 aus der Brakeman-Sichtung 21-05): `Version.update_carambus` holte die
# aktuelle Revision per HTTP von der Authority und setzte sie UNGEPRUEFT in eine
# Shell-Kommandozeile:
#
#   `REVISION=#{revision} bash -x #{Rails.root}/bin/deploy.sh 2>&1`
#
# Der Backtick fuehrt ueber /bin/sh aus — wer die HTTP-Antwort bestimmt, bestimmt das Kommando.
# Der Kanal ist zwar TLS-geprueft (Carambus.ssl_verify_mode = VERIFY_PEER), aber die Zeile
# selbst traegt keine Sicherung, und `CARAMBUS_TLS_INSECURE=1` ist ein dokumentierter Notausstieg.
#
# Zwei Schichten sind der Fix: (1) `valid_revision?` laesst nur Commit-Hashes durch,
# (2) die Ausfuehrung laeuft ueber eine Argumentliste, der Wert steht in der UMGEBUNG.
#
# ⚠️ Jeder Test hier faengt BEIDE Ausfuehrungskanaele ab (Backtick und Open3). Ungestubbt
# wuerde der Lauf gegen den alten Code `bin/deploy.sh` wirklich starten — die Datei existiert
# im Checkout.
class VersionUpdateCarambusTest < ActiveSupport::TestCase
  # Faengt Backtick und Open3 ab. `cat .../REVISION` wird mit `local_revision` beantwortet,
  # alles andere gilt als Ausfuehrungsversuch und wird protokolliert.
  def capture_executions(api_revision:, local_revision: "")
    executed = []
    json = {current_revision: api_revision}.to_json

    backtick = lambda do |cmd|
      next local_revision if cmd.to_s.start_with?("cat ")
      executed << {channel: :shell, cmd: cmd}
      ""
    end
    capture2e = lambda do |*args|
      executed << {channel: :open3, args: args}
      ["", nil]
    end

    Version.stub(:http_get_with_ssl_bypass, json) do
      Version.stub(:`, backtick) do
        Open3.stub(:capture2e, capture2e) do
          Version.update_carambus
        end
      end
    end
    executed
  end

  # ---------------------------------------------------------------------------
  # valid_revision? — die Form eines Git-Commit-Hashes
  # ---------------------------------------------------------------------------

  test "valid_revision? nimmt echte Commit-Hashes an" do
    assert Version.valid_revision?("d06a58e7")
    assert Version.valid_revision?("d06a58e7f1c2b3a4d5e6f7089a0b1c2d3e4f5061")
    assert Version.valid_revision?("abc1234")
  end

  test "valid_revision? weist alles ab, was kein Commit-Hash ist" do
    [
      nil, "", "   ",
      "abc123; touch /tmp/pwned",          # Kommandotrenner
      "abc123 && rm -rf /",                # Verkettung
      "abc123`whoami`",                    # Unterbefehl
      "abc123$(id)",                       # Unterbefehl
      "abc123\nrm -rf /",                  # Zeilenumbruch
      "abc123 -x",                         # Leerzeichen/Option
      "D06A58E7",                          # Grossbuchstaben (git liefert klein)
      "abc12",                             # zu kurz
      "d06a58e7f1c2b3a4d5e6f7089a0b1c2d3e4f50611" # zu lang
    ].each do |bad|
      refute Version.valid_revision?(bad), "#{bad.inspect} haette abgewiesen werden muessen"
    end
  end

  # ---------------------------------------------------------------------------
  # update_carambus — das Verhalten am Ende der Kette
  # ---------------------------------------------------------------------------

  test "eine Revision mit Shell-Metazeichen loest NICHTS aus" do
    executed = capture_executions(api_revision: "abc1234; touch /tmp/carambus_pwned")

    assert_empty executed,
      "Die Antwort der Authority wurde ausgefuehrt: #{executed.inspect}"
  end

  test "ein gueltiger, abweichender Hash startet den Deploy — mit REVISION in der Umgebung" do
    executed = capture_executions(api_revision: "d06a58e7", local_revision: "0000000")

    assert_equal 1, executed.size, "Der Deploy muss weiterhin starten (Verhaltenserhalt)"
    run = executed.first
    assert_equal :open3, run[:channel], "Der Deploy darf nicht mehr ueber die Shell laufen"

    env = run[:args].first
    assert_kind_of Hash, env, "Erstes Argument muss die Umgebung sein"
    assert_equal "d06a58e7", env["REVISION"], "REVISION gehoert in die Umgebung, nicht in die Kommandozeile"

    argv = run[:args][1..]
    assert_equal "bash", argv.first
    assert argv.any? { |a| a.to_s.end_with?("bin/deploy.sh") }, "deploy.sh fehlt in der Argumentliste"
    refute argv.any? { |a| a.to_s.include?("REVISION=") },
      "REVISION steht weiterhin in der Kommandozeile"
  end

  test "ein gleicher Hash loest keinen Deploy aus" do
    executed = capture_executions(api_revision: "d06a58e7", local_revision: "d06a58e7")

    assert_empty executed, "Bei gleichem Stand darf nichts laufen (unveraendertes Verhalten)"
  end
end
