class AddTemplateReferenceToTournaments < ActiveRecord::Migration
  def change
    add_column :tournaments, :tournament_plan_id, :integer
  end
end
