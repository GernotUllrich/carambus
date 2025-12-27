class AddAutoUploadToCcToTournamentLocals < ActiveRecord::Migration[7.2]
  def change
    add_column :tournament_locals, :auto_upload_to_cc, :boolean, default: true, null: false
  end
end
