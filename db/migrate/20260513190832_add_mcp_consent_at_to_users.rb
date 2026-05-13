class AddMcpConsentAtToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :mcp_consent_at, :datetime
  end
end
