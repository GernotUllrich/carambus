# frozen_string_literal: true

module Diagnostics
  # Findet Turniere, deren CC-Zuordnung sich selbst widerspricht — STRIKT READ-ONLY.
  #
  # Anlass (2026-08-27): "NDM Jugend Freie Partie" erschien im Kalender unter der Gruppe
  # Vorgabepokal. Der Filter war korrekt, die Quelle nicht: `TournamentCc #26255` traegt
  # `shortname "1VP"`, `category_cc_id 15` und `championship_type_cc_name "Vorgabepokal (VP)"` —
  # offenbar eine in der ClubCloud kopierte und umbenannte, aber nicht umkategorisierte Anlage.
  #
  # Solche Faelle sind von aussen unsichtbar: die Seite zeigt gehorsam, was die Daten sagen.
  # Diese Pruefung macht sie sichtbar. Sie repariert NICHTS — die Korrektur gehoert in die
  # CC-Quelle, eine lokale Aenderung wuerde der naechste Scrape ueberschreiben.
  class TournamentTypeCheck
    # Turnierserien, die einander ausschliessen. Bewusst nach FAMILIEN gruppiert:
    #
    # ⚠️ Gemessen am 2026-08-27 ueber 5180 CC-Zwillinge: ohne die Familien meldet die Pruefung
    # 82 Faelle, davon 81 harmlos — "GP" im Titel bei Typ "GGP" ist dieselbe Serie kuerzer
    # geschrieben (16x), "LJM" bei Typ "LEM" bzw. "NDJM" bei "NDM" sind Jugend-Varianten
    # derselben Meisterschaft (30x), und eine Landesmeisterschaft, die im Titel eine
    # DM-Qualifikation erwaehnt, ist kein Widerspruch (35x).
    #
    # Ein Widerspruch liegt vor, wenn zwei Angaben aus VERSCHIEDENEN Familien stammen.
    FAMILIEN = {
      "Meisterschaft" => %w[NDM NDJM DM DJM LEM LMJ LJM LM],
      "Grand Prix" => %w[GP GGP],
      "NordCup" => %w[NC],
      "Petit Prix" => %w[PP],
      "Vorgabepokal" => %w[VP]
    }.freeze

    CODES = FAMILIEN.values.flatten.freeze

    def initialize(verbose: false)
      @verbose = verbose
    end

    def call
      checks = [kategorie_gegen_typ, titel_gegen_typ]
      checks << varianten_hinweis if @verbose
      checks
    end

    private

    # Zerlegt "Vorgabepokal (VP)" in ["Vorgabepokal", "VP"].
    def zerlege(typ)
      m = typ.to_s.squeeze(" ").strip.match(/\A(.*?)\s*\(([^)]+)\)\s*\z/)
      m ? [m[1].strip, m[2].strip.upcase] : [typ.to_s.strip, nil]
    end

    def familie(code)
      FAMILIEN.find { |_, codes| codes.include?(code.to_s.upcase) }&.first
    end

    # Serien-Codes, die im Titel als eigenstaendiges Wort stehen.
    def codes_im_titel(titel)
      gross = titel.to_s.upcase
      CODES.select { |c| gross.match?(/(\A|[^A-ZÄÖÜ])#{Regexp.escape(c)}([^A-ZÄÖÜ]|\z)/) }
    end

    def zwillinge
      TournamentCc.where.not(championship_type_cc_name: [nil, ""])
        .includes(:category_cc, :tournament)
    end

    # --- Befund 1: die Kategorie widerspricht dem Meisterschaftstyp -------------------------

    def kategorie_gegen_typ
      treffer = zwillinge.select do |tcc|
        kat = tcc.category_cc&.name
        lang, kurz = zerlege(tcc.championship_type_cc_name)
        next false if kat.blank? || lang.blank?
        next false if kat.casecmp?(lang) || (kurz && kat.casecmp?(kurz))

        # Nur wenn die Kategorie ueberhaupt eine Serie meint — CategoryCc traegt daneben auch
        # Alters- und Geschlechtsklassen ("Herren", "Unisex jeden Alters"), die zum Typ gar
        # keine Aussage machen.
        FAMILIEN.keys.any? { |f| kat.casecmp?(f) } || CODES.any? { |c| kat.casecmp?(c) }
      end

      befund("Kategorie gegen Meisterschaftstyp", treffer) do |tcc|
        "#{titel_von(tcc)} — Typ #{tcc.championship_type_cc_name.inspect}, " \
          "Kategorie #{tcc.category_cc&.name.inspect}"
      end
    end

    # --- Befund 2: der Titel nennt eine Serie einer anderen Familie -------------------------

    def titel_gegen_typ
      treffer = zwillinge.select do |tcc|
        _, kurz = zerlege(tcc.championship_type_cc_name)
        eigene = familie(kurz)
        next false if eigene.nil?

        fremde = codes_im_titel(titel_von(tcc)).map { |c| familie(c) }.compact.uniq
        fremde.any? && fremde.none?(eigene)
      end

      befund("Titel gegen Meisterschaftstyp", treffer) do |tcc|
        "#{titel_von(tcc)} — Typ #{tcc.championship_type_cc_name.inspect}, " \
          "Titel nennt #{codes_im_titel(titel_von(tcc)).join(", ")}"
      end
    end

    # --- Optional: Varianten innerhalb einer Familie (NDM/NDJM, GP/GGP) --------------------

    def varianten_hinweis
      treffer = zwillinge.select do |tcc|
        _, kurz = zerlege(tcc.championship_type_cc_name)
        next false if familie(kurz).nil?

        codes = codes_im_titel(titel_von(tcc))
        codes.any? && !codes.include?(kurz) && codes.any? { |c| familie(c) == familie(kurz) }
      end

      Check.new(
        name: "Varianten innerhalb einer Familie",
        status: treffer.empty? ? :ok : :info,
        detail: "#{treffer.size} Turnier(e) — z.B. Titel 'NDJM' bei Typ 'NDM'",
        hint: beispiele(treffer) { |tcc| "#{titel_von(tcc)} — Typ #{tcc.championship_type_cc_name.inspect}" }
      )
    end

    # --- Ausgabe ---------------------------------------------------------------------------

    def titel_von(tcc)
      tcc.tournament&.title.presence || tcc.name.to_s
    end

    def befund(name, treffer, &beschreibung)
      Check.new(
        name: name,
        status: treffer.empty? ? :ok : :warn,
        detail: treffer.empty? ? "keine Widersprueche" : "#{treffer.size} Widerspruch/Widersprueche",
        hint: beispiele(treffer, &beschreibung)
      )
    end

    # Hoechstens zehn Zeilen — wer mehr braucht, ruft den Service direkt. Ein Diagnose-Tool, das
    # hundert Zeilen ausschuettet, wird nicht gelesen.
    def beispiele(treffer, &beschreibung)
      return nil if treffer.empty?

      zeilen = treffer.first(10).map { |tcc| "TournamentCc ##{tcc.id}: #{yield(tcc)}" }
      zeilen << "… und #{treffer.size - 10} weitere" if treffer.size > 10
      zeilen << "Korrektur gehoert in die CC-Quelle — lokal geaendert, ueberschreibt der naechste Scrape."
      zeilen.join("\n")
    end
  end
end
