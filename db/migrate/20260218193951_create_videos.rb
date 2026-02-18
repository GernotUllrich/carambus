class CreateVideos < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    create_table :videos do |t|
      # Basis-Info
      t.string :external_id, null: false
      t.string :title
      t.text :description
      t.string :thumbnail_url
      
      # Video-Meta
      t.integer :duration
      t.datetime :published_at
      t.integer :view_count
      t.integer :like_count
      t.string :language
      
      # Source (YouTube, Kozoom, Vimeo, etc.)
      t.references :international_source, foreign_key: { validate: false }
      
      # Polymorphe Association
      t.references :videoable, polymorphic: true
      
      # Metadata & Processing
      t.jsonb :data, default: {}
      t.boolean :metadata_extracted, default: false
      t.datetime :metadata_extracted_at
      
      # Optional: Discipline detection
      t.references :discipline, foreign_key: { validate: false }
      
      t.timestamps
    end
    
    # Indexes
    add_index :videos, :external_id, unique: true, algorithm: :concurrently
    add_index :videos, :published_at, algorithm: :concurrently
    add_index :videos, :metadata_extracted, algorithm: :concurrently
    add_index :videos, [:videoable_type, :videoable_id, :published_at],
              name: 'idx_videos_on_videoable_and_published',
              algorithm: :concurrently
  end
end
