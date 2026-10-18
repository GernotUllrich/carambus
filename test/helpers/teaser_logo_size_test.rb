# frozen_string_literal: true

require "test_helper"

# Vereinswappen im Scoreboard-Teaser (app/views/table_monitors/_teaser.html.erb).
#
# 23. DBU Grand Prix Biathlon, 18.10.2026: die Turnieruebersicht lief auf einem Saal-Fernseher.
# Namen und Punktestaende skalierten mit (Schriftgroessen in vw), die Wappen blieben bei festen
# h-10 w-20 = 40 x 80 px — bei 3vw auf einem 4K-Panel ein Drittel der Buchstabenhoehe. Auf dem
# 1440er Laptop fiel es nie auf, weil dort 40 px und 2vw zufaellig zusammenfallen.
#
# Pruefbar ist hier nur der ausgelieferte Markup — die em-Auflösung passiert im Browser. Das
# Partial nimmt `options` als Local (Zeile 5-8), deshalb laesst sich ein Wappen einspeisen,
# ohne Clubs und Spieler aufzubauen.
#
# Erwartungswerte aus HANDOFF-to-carambus-teaser-logo-groesse.md.
class TeaserLogoSizeTest < ActionView::TestCase
  # Echte Wappen-URLs von den Verbandsservern; der Test laedt sie nicht, image_tag gibt nur
  # den Pfad aus. Naturgroessen laut Handoff: 100x100 bzw. 137x200 (hochkant).
  LOGO_QUADRATISCH = "https://ndbv.de/images/wappen/1015.gif"
  LOGO_HOCHKANT = "https://westfalenbillard.net/images/wappen/1293.gif"

  setup do
    @table_monitor = table_monitors(:one)
    @table_monitor.get_options!(I18n.locale)
    @options = @table_monitor.options.deep_dup
    @options[:player_a][:logo] = LOGO_QUADRATISCH
    @options[:player_b][:logo] = LOGO_HOCHKANT
  end

  def teaser_html
    render(partial: "table_monitors/teaser",
      locals: {table_monitor: @table_monitor, options: @options})
  end

  test "Vorbedingung: mit Wappen rendert das Partial zwei img-Tags" do
    assert_equal 2, teaser_html.scan("<img").size,
      "Ohne img-Tags prueft der Test nichts — dann stimmt die Options-Einspeisung nicht"
  end

  test "die Wappengroesse ist relativ zur Schrift, nicht fest" do
    html = teaser_html

    assert_includes html, "height: 1.4em", "Hoehe muss an der geerbten Schriftgroesse haengen"
    assert_includes html, "width: 1.4em", "Breite ebenso — die Box ist quadratisch"
  end

  # ⚠️ Der eigentliche Fehler war die feste Box. Ein Test, der nur das Neue prueft, wuerde
  # nicht merken, wenn beides gleichzeitig im Markup steht — dann gewaenne die Klasse.
  test "die festen 40 x 80 px sind weg" do
    html = teaser_html

    refute_includes html, "h-10", "h-10 (40 px) darf im Teaser nicht mehr stehen"
    refute_includes html, "w-20", "w-20 (80 px) darf im Teaser nicht mehr stehen"
  end

  # object-contain ist das Einzige, was die hochkanten Wappen vor dem Stauchen bewahrt.
  test "object-contain bleibt erhalten" do
    assert_equal 2, teaser_html.scan("object-contain").size,
      "Ohne object-contain wird das 137x200er Wappen in die quadratische Box gestaucht"
  end

  # Untergrenze fuers Telefon: bei 2vw / 390 px waeren 1.4em rund 11 px.
  test "Untergrenze fuer kleine Bildschirme ist gesetzt" do
    html = teaser_html

    assert_includes html, "min-height: 1.5rem"
    assert_includes html, "min-width: 1.5rem"
  end

  # Beide Spieler, nicht nur der linke — die beiden Zeilen (60 und 92) sind getrennt gepflegt
  # und schon einmal auseinandergelaufen waere unbemerkt geblieben.
  test "beide Wappen tragen dieselbe Groessenangabe" do
    html = teaser_html

    assert_equal 2, html.scan("height: 1.4em").size,
      "Linker UND rechter Spieler muessen die relative Groesse haben"
    assert_includes html, LOGO_QUADRATISCH
    assert_includes html, LOGO_HOCHKANT
  end
end
