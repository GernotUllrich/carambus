class AddSeqnoToGames < ActiveRecord::Migration
  def change
    add_column :games, :seqno, :integer
  end
end
