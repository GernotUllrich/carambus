class AddPreferencesToUsers < ActiveRecord::Migration[7.0]
  def change
    safety_assured {
      change_table :users do |t|
        if t.respond_to?(:jsonb)
          t.jsonb :preferences
        else
          t.json :preferences
        end
      end
    }
  end
end
