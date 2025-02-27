class CreatePages < ActiveRecord::Migration[7.0]
  def change
    create_table :pages do |t|
      t.string :title, null: false
      t.text :content
      t.text :summary
      t.integer :super_page_id
      t.integer :position
      t.string :author_type
      t.integer :author_id
      t.string :content_type, default: 'markdown'
      t.integer :status, default: 0
      t.datetime :published_at
      t.jsonb :tags, default: []
      t.jsonb :metadata, default: {}
      t.jsonb :crud_minimum_roles, default: {
        'create' => 'system_admin',
        'read' => 'player',
        'update' => 'system_admin',
        'delete' => 'system_admin'
      }
      t.string :version, default: '0.1'

      t.timestamps
    end

    add_index :pages, :super_page_id
    add_index :pages, [:author_type, :author_id]
    add_index :pages, :status
    add_index :pages, :tags, using: :gin
  end
end
