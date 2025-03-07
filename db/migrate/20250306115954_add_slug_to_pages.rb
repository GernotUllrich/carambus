[class AddSlugToPages < ActiveRecord::Migration[7.2]
  def up
    add_column :pages, :slug, :string, null: false, default: ""
    Page.all.each do |page|
      page.update(slug: page.title.parameterize)
    end
  end
  def down
    remove_column :pages, :slug
  end
end
]
