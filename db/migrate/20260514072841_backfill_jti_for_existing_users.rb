# frozen_string_literal: true

class BackfillJtiForExistingUsers < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    User.unscoped.where(jti: nil).find_each(batch_size: 1000) do |user|
      user.update_columns(jti: SecureRandom.uuid)
    end
  end

  def down
  end
end
