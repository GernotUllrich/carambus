class AlterDisciplinesIdInTournaments < ActiveRecord::Migration
  def change
    change_column_null :tournaments, :discipline_id, false
  end
end
