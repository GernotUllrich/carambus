class AddCcId2Gt < ActiveRecord::Migration[7.0]
  def change
    add_column :leagues, :cc_id2, :integer
    League.joins(:league_cc).where.not(league_ccs: {cc_id2: nil}).each do |l|
      l.update(cc_id2: l.league_cc.cc_id2)
    end
  end
end
