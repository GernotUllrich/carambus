# frozen_string_literal: true

# Anmeldung im Spielerkontext (Plan 02.1-01).
#
# ⚠️ Das ist KEINE Benutzeranmeldung und kein zweiter Devise-Scope. Der Spieler wird ohnehin
# aus der Liste gewaehlt; der PIN bestaetigt nur, dass es wirklich er ist. `current_user`
# bleibt unberuehrt — am Kiosk ist das weiterhin der Scoreboard-Sammelaccount.
#
# ⚠️ Anmelden ist OPTIONAL. Ohne Anmeldung verhaelt sich die Anwendung exakt wie vorher,
# insbesondere laesst sich ein Trainingsspiel unveraendert starten.
class PlayerSessionsController < ApplicationController
  def new
    return redirect_to player_session_path if player_signed_in?

    @players = PlayerLocal.selectable_players
  end

  # Der Landeplatz aus 02.1-01 ist durch den persoenlichen Bereich ersetzt (Plan 02.1-02).
  # Die Route bleibt bestehen, damit alte Links und Lesezeichen weiter funktionieren.
  def show
    return redirect_to new_player_session_path unless player_signed_in?

    redirect_to player_profile_path
  end

  def create
    kontakt = kontakt_fuer(params[:player_id])

    if kontakt&.verify_pin(params[:pin])
      sign_in_player(kontakt)
      return redirect_to player_profile_path
    end

    @players = PlayerLocal.selectable_players
    # ⚠️ Bei Sperre die verbleibende Zeit nennen — das Konto ist ohnehin identifiziert, und
    # ohne diese Rueckmeldung haelt der Betrachter die Sperre fuer einen falschen PIN.
    flash.now[:alert] = if kontakt&.pin_locked?
      t(".locked", minuten: (kontakt.pin_lock_remaining / 60.0).ceil)
    else
      # ⚠️ EINE Meldung fuer alle Fehlerfaelle — unbekannter Spieler, kein PIN gesetzt,
      # falscher PIN. Getrennte Meldungen verrieten, wer ueberhaupt einen PIN hat.
      t(".invalid")
    end
    render :new, status: :unprocessable_entity
  end

  def destroy
    sign_out_player
    redirect_to new_player_session_path, notice: t(".signed_out")
  end

  private

  # Nur Clubmitglieder der laufenden Saison — derselbe Personenkreis wie im Admin-Dashboard.
  # Ein `player_id` von ausserhalb dieser Menge fuehrt zur einheitlichen Fehlermeldung.
  def kontakt_fuer(player_id)
    return nil if player_id.blank?
    return nil unless PlayerLocal.selectable_players.exists?(id: player_id)

    PlayerLocal.find_by(player_id: player_id)
  end
end
