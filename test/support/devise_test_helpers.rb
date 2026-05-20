# frozen_string_literal: true

# D-41-A Wave-0 Skeleton (VALIDATION.md Pflichtlieferung).
#
# Aktueller Stand: Plan-05 System-Tests definieren sign_in_via_form als private
# Method inline. Dieser Module ist Reserve fuer spaetere DRY-Refactoring oder
# zusaetzliche Helper (z.B. confirmed_user-Factory, raw-Confirmation-Token-
# Generator). Plan-02..05 erweitern bei Bedarf.
module DeviseTestHelpers
  # Placeholder: generiert ein Raw-Confirmation-Token + speichert digest am User.
  # Devise nutzt Devise.token_generator.generate(User, :confirmation_token).
  def generate_raw_confirmation_token(user)
    raw, db = Devise.token_generator.generate(User, :confirmation_token)
    user.update_columns(confirmation_token: db, confirmation_sent_at: Time.current)
    raw
  end
end
