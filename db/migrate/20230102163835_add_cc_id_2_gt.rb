class AddCcId2Gt < ActiveRecord::Migration[7.0]
  def change
    add_column :leagues, :cc_id2, :integer

    # Use SQL instead of ActiveRecord to avoid model dependencies
    safety_assured do
      execute <<-SQL
        UPDATE leagues 
        SET cc_id2 = league_ccs.cc_id2 
        FROM league_ccs 
        WHERE leagues.id = league_ccs.league_id 
        AND league_ccs.cc_id2 IS NOT NULL
      SQL
    end
  end
end
