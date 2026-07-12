# frozen_string_literal: true

require "test_helper"
require "rake"

# Unit-Tests fuer Discipline.classify_from_title (Titel -> exakte Disziplin) und den
# idempotenten Synonym-Extend-Task (Plan 03-01). Hermetisch: legt die noetigen
# Disziplinen selbst an (Fixtures sind fuer den Matcher unvollstaendig) und setzt den
# memoisierten classify_index zurueck.
class DisciplineClassifyTest < ActiveSupport::TestCase
  BASE = 53_000_000

  setup do
    # Kegel-Branch + Kegel-Disziplin (root-basierte Kegel-Scoping-Regel)
    @kegel = Branch.create!(id: BASE + 50, name: "Kegel")
    Discipline.create!(id: BASE + 58, name: "Eurokegel", super_discipline_id: @kegel.id)
    # Karambol gross/klein (Matcher waehlt per Name; gross=Default)
    Discipline.create!(id: BASE + 31, name: "Dreiband groß")
    Discipline.create!(id: BASE + 33, name: "Dreiband klein")
    # Cadre (Format pinnt exakt) + Snooker
    Discipline.create!(id: BASE + 40, name: "Cadre 47/2")
    Discipline.create!(id: BASE + 91, name: "Snooker (15reds)")
    # Pool: Branch + Blatt-Disziplinen (Blatt-vor-Branch-Praezedenz, Plan 03-03)
    @pool = Branch.create!(id: BASE + 23, name: "Pool")
    Discipline.create!(id: BASE + 51, name: "10-Ball", synonyms: "10er Ball\n10 Ball", super_discipline_id: @pool.id)
    Discipline.create!(id: BASE + 46, name: "14.1 endlos", synonyms: "14/1", super_discipline_id: @pool.id)

    Discipline.reset_classify_index!
  end

  teardown { Discipline.reset_classify_index! }

  def name_of(title)
    Discipline.classify_from_title(title)&.name
  end

  test "AC-1: leitet exakte Disziplin aus dem Titel ab" do
    assert_equal "10-Ball", name_of("Landesmeisterschaft 10er Ball Herren")
    assert_equal "10-Ball", name_of("BLMR Quali LM Herrn 10 Ball")
    assert_equal "Dreiband groß", name_of("BM Dreiband (gb) - III Klasse"), "ohne Klein-Marker -> grosser Tisch (Default)"
    assert_equal "Dreiband klein", name_of("LM Dreiband kl."), "Klein-Marker -> kleiner Tisch"
    assert_equal "Cadre 47/2", name_of("LM Cadré 47/2"), "Cadre-Format pinnt die exakte Disziplin"
    assert_equal "Snooker (15reds)", name_of("Bezirksmeisterschaft 15-reds Herren")
    assert_equal "Eurokegel", name_of("Teampokal Eurokegel 2023"), "Kegel-Branch-Scoping + Synonym-Match"
  end

  test "AC-3: nicht ableitbare Titel -> nil (Triage)" do
    assert_nil name_of("UMB General Assembly"), "internationales Sammelevent ohne Disziplin"
    assert_nil name_of("Jahresabschlussturnier 2023")
    assert_nil name_of(""), "leerer Titel"
  end

  # Plan 03-03: Blatt schlaegt Branch; Branch ist gueltiger Fallback (User-Entscheidung).
  test "Blatt schlaegt Branch, Branch als Fallback" do
    assert_equal "14.1 endlos", name_of("Sächsische Landesmeisterschaft Pool 14/1 Herren"),
      "Blatt (14.1 endlos) schlaegt Branch (Pool)"
    assert_equal "Pool", name_of("Friday for Pool (PBF Blieskastel)"), "kein Blatt -> Pool-Branch"
    assert_equal "Kegel", name_of("Landesjugendmeisterschaft BK U15"), "BK ohne exakte Kegel-Disziplin -> Kegel-Branch"
    assert_equal "Kegel", name_of("Landesjugendmeisterschaft Kegel U15"), "generisches Kegel -> Kegel-Branch"
  end

  test "3C/3CC -> Dreiband groß" do
    assert_equal "Dreiband groß", name_of("Survival 3C Masters")
    assert_equal "Dreiband groß", name_of("3CC Masters")
  end

  test "AC-2: extend_title_synonyms ist idempotent + dry-run mutiert nicht" do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    task = Rake::Task["disciplines:extend_title_synonyms"]

    # Ziel-Disziplin, die in den Fixtures existiert
    d = Discipline.find_by(name: "8-Ball")
    assert d, "Fixture 8-Ball erwartet"
    refute_includes d.synonyms.to_s.split("\n"), "8 Ball", "Vorbedingung: Synonym noch nicht vorhanden"

    # DRY-RUN: keine Mutation
    ENV.delete("ARMED")
    capture_io {
      task.reenable
      task.invoke
    }
    refute_includes d.reload.synonyms.to_s.split("\n"), "8 Ball", "DRY-RUN darf nicht mutieren"

    # ARMED: ergaenzt
    ENV["ARMED"] = "1"
    capture_io {
      task.reenable
      task.invoke
    }
    assert_includes d.reload.synonyms.to_s.split("\n"), "8 Ball", "ARMED muss das Synonym ergaenzen"

    # 2. ARMED-Lauf: No-op (keine Dublette)
    before = d.reload.synonyms.to_s.split("\n").size
    capture_io {
      task.reenable
      task.invoke
    }
    assert_equal before, d.reload.synonyms.to_s.split("\n").size, "zweiter Lauf darf nichts ergaenzen"
  ensure
    ENV.delete("ARMED")
    Rake::Task.clear
  end
end
