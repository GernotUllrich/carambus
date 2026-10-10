# frozen_string_literal: true

require "test_helper"
require "tmpdir"

# 2026-10-10: Das Lock, das das Dashboard beim Speichern anlegt, landete im RELEASE statt in
# shared/ — und war damit beim naechsten Deploy weg, waehrend die carambus.yml selbst (ein
# linked_file) ueberlebte. Der Uploader in scenarios.rake sucht es per `test -f` in
# shared/config/; beide Seiten waren fuer sich korrekt, nur trafen sie sich nie.
#
# Carambus.config_lock_path loest den Symlink auf und legt das Lock neben die ECHTE Datei.
class CarambusConfigLockPathTest < ActiveSupport::TestCase
  test "gewoehnliche Datei: Lock liegt daneben" do
    Dir.mktmpdir do |roh|
      # ⚠️ File.realpath loest JEDE Pfadkomponente auf, nicht nur die letzte — und auf macOS
      # ist /var ein Symlink auf /private/var. Ohne dieses Normalisieren vergleicht der Test
      # zwei Schreibweisen desselben Pfades und schlaegt aus dem falschen Grund fehl.
      dir = File.realpath(roh)
      cfg = File.join(dir, "carambus.yml")
      File.write(cfg, "default: {}\n")

      assert_equal "#{cfg}.lock", Carambus.config_lock_path(cfg).to_s
    end
  end

  # Der Fall, um den es geht: auf dem Server ist config/carambus.yml ein Symlink nach
  # shared/config/. Das Lock muss beim Ziel landen, nicht beim Link.
  test "Symlink: Lock liegt beim Ziel, nicht beim Link" do
    Dir.mktmpdir do |roh|
      dir = File.realpath(roh) # siehe Kommentar im Test darueber
      shared = File.join(dir, "shared", "config")
      release = File.join(dir, "releases", "20261010", "config")
      FileUtils.mkdir_p(shared)
      FileUtils.mkdir_p(release)

      ziel = File.join(shared, "carambus.yml")
      File.write(ziel, "default: {}\n")
      link = File.join(release, "carambus.yml")
      File.symlink(ziel, link)

      ergebnis = Carambus.config_lock_path(link).to_s

      assert_equal "#{ziel}.lock", ergebnis,
        "Das Lock muss in shared/config/ landen — dort sucht config_file_locked? danach"
      refute_equal "#{link}.lock", ergebnis,
        "Im Release angelegt waere es beim naechsten Deploy weg (genau der Defekt von 2026-10-10)"
      assert_includes ergebnis, "shared/config"
      refute_includes ergebnis, "releases"
    end
  end

  # Ohne Datei kann nichts aufgeloest werden — dann gilt der uebergebene Pfad. Sonst wuerde
  # ein frischer Checkout ohne carambus.yml beim Speichern mit Errno::ENOENT abbrechen.
  test "fehlende Datei: Lock neben dem angefragten Pfad" do
    Dir.mktmpdir do |dir|
      cfg = File.join(dir, "gibtesnicht.yml")

      assert_equal "#{cfg}.lock", Carambus.config_lock_path(cfg).to_s
    end
  end

  # ⚠️ Die Pruefung muss auf EXISTENZ gehen, nicht auf den Link: ein baumelnder Symlink darf
  # nicht als „gesperrt" gelten. File.exist? folgt dem Link und meldet false — File.symlink?
  # waere hier die falsche Frage.
  test "baumelnder Symlink gilt nicht als gesperrt" do
    Dir.mktmpdir do |dir|
      lock = File.join(dir, "carambus.yml.lock")
      File.symlink(File.join(dir, "weg"), lock)

      assert File.symlink?(lock), "Vorbedingung: es IST ein Symlink"
      refute File.exist?(lock),
        "Ein Symlink ins Leere darf nicht als vorhandenes Lock durchgehen"
    end
  end

  test "ohne Argument gilt die echte config/carambus.yml" do
    erwartet = "#{File.realpath(Rails.root.join("config", "carambus.yml"))}.lock"

    assert_equal erwartet, Carambus.config_lock_path.to_s
  end
end
