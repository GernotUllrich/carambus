# frozen_string_literal: true

# Das Mitglied setzt seinen PIN ueber einen Einmal-Link selbst (Plan 02.2-01).
#
# ⚠️ OEFFENTLICHER ENDPUNKT. Keine Anmeldung, und der Clubserver ist per DynDNS aus dem
# Internet erreichbar. Daraus folgen zwei Regeln, die hier nicht verhandelbar sind:
#
#   1. Der Datensatz wird AUSSCHLIESSLICH ueber `find_by_token_for` aufgeloest. Der Token ist
#      signiert und traegt seinen Ablauf selbst — eine id aus dem Pfad gibt es gar nicht.
#   2. Ein ungueltiger Token fuehrt zu EINER unspezifischen Meldung. Kein Name, keine Adresse,
#      kein Hinweis darauf, ob es das Konto gibt — sonst wird die Seite zum Auskunftsdienst.
#
# ⚠️ Bewusst KEINE Sperr-Logik: der Token ist signiert und nicht erratbar. Ein
# Fehlversuchszaehler waere hier Zierrat (die Sperre gehoert zur Anmeldung, wo geraten werden
# kann).
class PinSetupsController < ApplicationController
  before_action :kontakt_aus_token

  def edit
  end

  def update
    neuer_pin = params[:pin].to_s
    wiederholung = params[:pin_confirmation].to_s

    if neuer_pin.blank?
      return abweisen(t(".blank"))
    end

    # ⚠️ Die Wiederholung ist Pflicht: ein Tippfehler beim erstmaligen Setzen sperrte das
    # Mitglied aus — und einen zweiten Link gibt es nicht, der alte ist danach entwertet.
    return abweisen(t(".mismatch")) unless neuer_pin == wiederholung

    if @kontakt.update(pin: neuer_pin)
      # Das Mitglied hat sich soeben ueber den Link ausgewiesen — es noch einmal nach dem
      # gerade gesetzten PIN zu fragen waere Schikane.
      sign_in_player(@kontakt)
      redirect_to player_profile_path, notice: t(".done")
    else
      abweisen(@kontakt.errors.full_messages.to_sentence)
    end
  end

  private

  def abweisen(meldung)
    flash.now[:alert] = meldung
    render :edit, status: :unprocessable_entity
  end

  def kontakt_aus_token
    @kontakt = PlayerLocal.find_by_token_for(:pin_setup, params[:token])
    return if @kontakt.present?

    # ⚠️ EINE Meldung fuer alle Faelle: erfunden, abgelaufen, bereits verbraucht. Jede
    # Unterscheidung waere eine Auskunft.
    render :invalid, status: :not_found
  end
end
