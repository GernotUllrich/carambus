class AddSynonymsToClubs < ActiveRecord::Migration[7.0]
  def change
    add_column :clubs, :synonyms, :text
    Club.all.each do |c|
      c.synonyms = (c.synonyms.to_s.split("\n") + [c.name, c.shortname]).uniq.join("\n")
      c.save!
    end
  end
end
