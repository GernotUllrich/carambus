# frozen_string_literal: true

# Einladung an ein Vereinsmitglied, seinen PIN selbst zu setzen (Plan 02.2-01).
#
# ⚠️ Diese Mail enthaelt KEINEN PIN — nur einen Einmal-Link. Ein gemailter PIN laege dauerhaft
# im Klartext im Postfach, wird mitsynchronisiert und weitergeleitet; der Login gilt seit
# Plan 02.1-01 auch ueber das offene Netz.
class PlayerLocalMailer < ApplicationMailer
  # ⚠️ `from` NICHT ueberschreiben. `ApplicationMailer` setzt es auf `Devise.mailer_sender`
  # (Plan 41-04) — ein abweichender Absender erzeugt SPF/DKIM-Mismatch und Gmail sortiert die
  # Mail als Spam ein.

  def pin_setup(player_local)
    @player_local = player_local
    @name = player_local.player&.fl_name

    # ⚠️ Der Guard steht HIER und nicht nur beim Aufrufer: ohne gueltige Einwilligung darf
    # keine Mail rausgehen, auch wenn ein kuenftiger Aufrufer das vergisst. `NullMail`
    # bedeutet: `deliver_now` laeuft durch, verschickt aber nichts.
    return NullMail.new unless player_local.contactable?

    @url = pin_setup_url(token: player_local.generate_token_for(:pin_setup))
    @gueltig_bis = (Time.current + PlayerLocal::PIN_SETUP_TOKEN_VALIDITY).to_date

    mail(to: player_local.email, subject: t("player_local_mailer.pin_setup.subject"))
  end
end
