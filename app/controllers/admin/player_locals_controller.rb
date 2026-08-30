# frozen_string_literal: true

module Admin
  # Pflege der lokalen Kontaktdaten. Der Zugriffsschutz kommt aus
  # `Admin::ApplicationController` (nur `system_admin?`).
  class PlayerLocalsController < Admin::ApplicationController
    # Nach Spielername sortiert statt nach id — die Liste wird gelesen, nicht durchnummeriert.
    def scoped_resource
      PlayerLocal.joins(:player).order(Player.sort_key_sql)
    end

    # Massenpflege der E-Mail-Adressen (Quick-Task 2026-08-30).
    #
    # WARUM: Administrate pflegt einen Datensatz je Formular. Bei 23 Clubmitgliedern hiesse das
    # 23 Mal anlegen, speichern, zurueck. Hier steht die ganze Mannschaft in einer Tabelle und
    # wird in einem Zug gespeichert.
    #
    # ⚠️ Die Zeilen werden ueber die SPIELER gebildet, nicht ueber vorhandene `PlayerLocal`s:
    # so erscheinen auch Mitglieder, fuer die es noch gar keinen Datensatz gibt — genau die,
    # um die es geht. Der Datensatz entsteht erst beim Speichern, und nur wenn es etwas zu
    # speichern gibt.
    def bulk_edit
      @players = PlayerLocal.selectable_players
      @locals = PlayerLocal.where(player_id: @players.map(&:id)).index_by(&:player_id)
      @fehler = {}
    end

    def bulk_update
      @players = PlayerLocal.selectable_players
      erlaubt = @players.map(&:id).to_set
      @locals = PlayerLocal.where(player_id: erlaubt.to_a).index_by(&:player_id)
      @fehler = {}
      geaendert = 0

      (params[:rows] || {}).each do |player_id, felder|
        pid = player_id.to_i
        # ⚠️ Nur Clubmitglieder — eine untergeschobene fremde player_id bleibt folgenlos.
        next unless erlaubt.include?(pid)

        kontakt = @locals[pid] || PlayerLocal.new(player_id: pid)
        email = felder[:email].to_s.strip
        einwilligung = felder[:consent].to_s == "1"

        # ⚠️ Nichts anlegen fuer eine leere Zeile ohne bestehenden Datensatz — sonst entstuenden
        # 23 leere Kontakte, sobald jemand das Formular einmal ohne Eingabe abschickt.
        next if kontakt.new_record? && email.blank? && !einwilligung

        kontakt.email = email
        if einwilligung && !kontakt.contactable?
          kontakt.consent_given_at = Time.current
          kontakt.consent_revoked_at = nil
        elsif !einwilligung && kontakt.consent_given_at.present? && kontakt.consent_revoked_at.blank?
          # Haken weg = Widerruf. ⚠️ Die Adresse bleibt stehen (Zusage aus 02.1-01).
          kontakt.consent_revoked_at = Time.current
        end

        if kontakt.changed? || kontakt.new_record?
          if kontakt.save
            geaendert += 1
          else
            # ⚠️ Fehlerhafte Zeilen duerfen die uebrigen nicht mitreissen: die gueltigen sind
            # bereits gespeichert, die fehlerhafte wird mit ihrer Eingabe zurueckgezeigt.
            @fehler[pid] = kontakt.errors.full_messages.to_sentence
          end
          # In beiden Faellen zurueck in die Tabelle — gespeichert oder mit der Eingabe,
          # die der Betrachter korrigieren soll.
          @locals[pid] = kontakt
        end
      end

      if @fehler.empty?
        redirect_to bulk_edit_admin_player_locals_path,
          notice: t("admin.player_locals.bulk.saved", count: geaendert)
      else
        flash.now[:alert] = t("admin.player_locals.bulk.partial",
          ok: geaendert, fehler: @fehler.size)
        render :bulk_edit, status: :unprocessable_entity
      end
    end

    # Nach dem Speichern zurueck zur Liste statt auf die Detailseite (Betreiber-Abnahme
    # 2026-08-30, Plan 02.1-01).
    #
    # ⚠️ Administrate leitet von Haus aus auf die SHOW-Seite. Das passt hier nicht: die
    # Kontaktdaten werden reihenweise gepflegt — man legt einen Datensatz an und will zum
    # naechsten Mitglied, nicht auf eine Detailseite, die ohnehin nur dasselbe zeigt.
    # Dieselbe Linie wie beim `destroy` in Admin::TrainingConceptsController.
    def after_resource_created_path(_requested_resource)
      admin_player_locals_path
    end

    def after_resource_updated_path(_requested_resource)
      admin_player_locals_path
    end
  end
end
