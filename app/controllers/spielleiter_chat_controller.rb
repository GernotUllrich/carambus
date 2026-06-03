# frozen_string_literal: true

class SpielleiterChatController < ApplicationController
  before_action :authenticate_user!

  SESSION_KEY = :spielleiter_chat_messages

  def show
    @messages = session_messages
  end

  def create
    user_text = params[:message].to_s.strip
    return redirect_to spielleiter_chat_path if user_text.blank?

    messages = session_messages + [{role: "user", content: user_text}]

    begin
      result = SpielleiterChatService.new(user: current_user).converse(messages: messages)
      session[SESSION_KEY] = result[:messages].last(40)
    rescue => e
      Rails.logger.error("[SpielleiterChatController] #{e.class}: #{e.message}")
      flash[:alert] = "Fehler beim Verarbeiten der Anfrage. Bitte erneut versuchen."
    end

    redirect_to spielleiter_chat_path
  end

  def destroy
    session.delete(SESSION_KEY)
    redirect_to spielleiter_chat_path
  end

  private

  def session_messages
    (session[SESSION_KEY] || []).map(&:symbolize_keys)
  end
end
