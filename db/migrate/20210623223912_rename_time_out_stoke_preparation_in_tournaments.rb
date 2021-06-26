class RenameTimeOutStokePreparationInTournaments < ActiveRecord::Migration[6.0]
  def change
    rename_column :tournaments, :time_out_stoke_preparation_sec, :timeout
  end
end
