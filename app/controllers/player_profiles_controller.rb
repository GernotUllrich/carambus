# frozen_string_literal: true

# Der persoenliche Bereich eines angemeldeten Vereinsmitglieds (Plan 02.1-02).
#
# ⚠️ **Der Datensatz kommt AUSSCHLIESSLICH aus `current_player_local`.** In diesem Controller
# wird NIE eine id aus `params` aufgeloest — sonst koennte jeder Angemeldete die Adresse eines
# beliebigen anderen Mitglieds aendern. Das ist die einzige Zugriffskontrolle, die es hier gibt,
# und sie traegt nur, solange dieser Satz gilt.
class PlayerProfilesController < ApplicationController
  before_action :require_player!

  def show
    @player_local = current_player_local
  end

  # Adresse und Einwilligung. Beides in einer Aktion, weil es ein Formular ist.
  def update
    @player_local = current_player_local

    case params[:consent]
    when "grant" then @player_local.grant_consent!
    when "revoke" then @player_local.revoke_consent!
    end

    # ⚠️ Nur anfassen, wenn das Feld ueberhaupt mitgeschickt wurde. Ein Formular, das NUR die
    # Einwilligung schickt, wuerde sonst mit `nil` die Adresse loeschen.
    attrs = {}
    attrs[:email] = params.dig(:player_local, :email) if params.dig(:player_local)&.key?(:email)

    if @player_local.update(attrs)
      redirect_to player_profile_path, notice: t(".saved")
    else
      flash.now[:alert] = @player_local.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  # PIN aendern.
  #
  # ⚠️ Der ALTE PIN wird verlangt. Ohne ihn koennte am unbeaufsichtigten Touchdisplay innerhalb
  # der Untaetigkeits-Spanne jeder das Konto uebernehmen. Geprueft wird mit `verify_pin` —
  # damit greift auch die Sperre nach Fehlversuchen, ein Fehlversuch hier zaehlt wie einer an
  # der Anmeldung. Beabsichtigt.
  def pin
    @player_local = current_player_local

    unless @player_local.verify_pin(params[:current_pin])
      flash.now[:alert] = if @player_local.pin_locked?
        t(".locked", minuten: (@player_local.pin_lock_remaining / 60.0).ceil)
      else
        t(".wrong_current_pin")
      end
      return render :show, status: :unprocessable_entity
    end

    # ⚠️ Ein leerer neuer PIN muss HIER abgefangen werden. `PlayerLocal#pin=` ignoriert leere
    # Werte (Guard gegen Administrates immer leeres Passwortfeld) — `update(pin: "")` waere
    # also erfolgreich, ohne etwas zu aendern, und die Oberflaeche meldete faelschlich
    # „PIN geaendert".
    if params[:new_pin].blank?
      flash.now[:alert] = t(".pin_blank")
      return render :show, status: :unprocessable_entity
    end

    # ⚠️ `update` (nicht `update!`): ein zu kurzer oder trivialer neuer PIN ist eine normale
    # Eingabe des Betrachters, kein Ausnahmefall. Bei Ablehnung bleibt der ALTE PIN gueltig,
    # weil `pin_digest` gar nicht erst geschrieben wird.
    if @player_local.update(pin: params[:new_pin])
      # ⚠️ Die Anmeldung NICHT beenden — das Mitglied steht vor dem Display und arbeitet weiter.
      redirect_to player_profile_path, notice: t(".pin_changed")
    else
      flash.now[:alert] = @player_local.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  private

  def require_player!
    return if player_signed_in?

    redirect_to "/player_session/new", alert: t("player_profiles.sign_in_required")
  end
end
