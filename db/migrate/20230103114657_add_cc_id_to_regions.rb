class AddCcIdToRegions < ActiveRecord::Migration[7.0]
  def change
    add_column :regions, :cc_id, :integer
    Region.joins(:region_cc).each do |region|
      region.update(cc_id: region.cc_id)
    end
  end
end
