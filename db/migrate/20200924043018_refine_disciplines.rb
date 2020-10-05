class RefineDisciplines < ActiveRecord::Migration
  MAJOR_DISCIPLINES = {
      "Pool" => {"table_kind" => ["Pool"]},
      "Snooker" => {"table_kind" => ["Snooker"]},
      "Pin Billards" => {"table_kind" => ["Small Table", "Match Table", "Large Table"]},
      "5-Pin Billards" => {"table_kind" => ["Small Table", "Match Table", "Large Table"]},
      "Carambol Large Table" => {"table_kind" => ["Large Table"]},
      "Carambol Small Table" => {"table_kind" => ["Small Table"]},
      "Biathlon" => {"table_kind" => ["Small Table"]}
  }
  def change
    add_column :disciplines, :super_discipline_id, :integer
    add_column :disciplines, :table_kind_id, :integer
    add_column :disciplines, :short_name, :string
    add_column :disciplines, :data, :text
  end


end
