namespace :training_data do
  desc "Export training data to db/seeds/training_data.rb"
  task export: :environment do
    require 'fileutils'
    
    FileUtils.mkdir_p('db/seeds')
    output_file = Rails.root.join('db/seeds/training_data.rb')
    
    File.open(output_file, 'w') do |f|
      f.puts "# Training Data Export"
      f.puts "# Generated: #{Time.current}"
      f.puts "# Use: rails training_data:import"
      f.puts ""
      f.puts "puts 'Importing training data...'"
      f.puts ""
      
      # Export TrainingSources
      f.puts "# Training Sources"
      TrainingSource.find_each do |source|
        f.puts "source_#{source.id} = TrainingSource.find_or_create_by(id: #{source.id}) do |s|"
        f.puts "  s.title = #{source.title.inspect}"
        f.puts "  s.author = #{source.author.inspect}"
        f.puts "  s.publication_year = #{source.publication_year.inspect}"
        f.puts "  s.publisher = #{source.publisher.inspect}"
        f.puts "  s.language = #{source.language.inspect}"
        f.puts "  s.notes = #{source.notes.inspect}"
        f.puts "end"
        f.puts ""
      end
      
      # Export TrainingConcepts
      f.puts "# Training Concepts"
      TrainingConcept.find_each do |concept|
        f.puts "concept_#{concept.id} = TrainingConcept.find_or_create_by(id: #{concept.id}) do |c|"
        f.puts "  c.title = #{concept.title.inspect}"
        f.puts "  c.title_de = #{concept.title_de.inspect}"
        f.puts "  c.title_en = #{concept.title_en.inspect}"
        f.puts "  c.short_description = #{concept.short_description.inspect}"
        f.puts "  c.short_description_de = #{concept.short_description_de.inspect}"
        f.puts "  c.short_description_en = #{concept.short_description_en.inspect}"
        f.puts "  c.full_description = #{concept.full_description.inspect}"
        f.puts "  c.full_description_de = #{concept.full_description_de.inspect}"
        f.puts "  c.full_description_en = #{concept.full_description_en.inspect}"
        f.puts "  c.source_language = #{concept.source_language.inspect}"
        f.puts "  c.translations_synced_at = #{concept.translations_synced_at.inspect}"
        f.puts "end"
        f.puts ""
      end
      
      # Export TrainingExamples
      f.puts "# Training Examples"
      TrainingExample.find_each do |example|
        f.puts "example_#{example.id} = TrainingExample.find_or_create_by(id: #{example.id}) do |e|"
        f.puts "  e.training_concept_id = #{example.training_concept_id}"
        f.puts "  e.sequence_number = #{example.sequence_number}"
        f.puts "  e.title = #{example.title.inspect}"
        f.puts "  e.title_de = #{example.title_de.inspect}"
        f.puts "  e.title_en = #{example.title_en.inspect}"
        f.puts "  e.ideal_stroke_parameters_text = #{example.ideal_stroke_parameters_text.inspect}"
        f.puts "  e.ideal_stroke_parameters_text_de = #{example.ideal_stroke_parameters_text_de.inspect}"
        f.puts "  e.ideal_stroke_parameters_text_en = #{example.ideal_stroke_parameters_text_en.inspect}"
        f.puts "  e.source_language = #{example.source_language.inspect}"
        f.puts "  e.source_notes = #{example.source_notes.inspect}"
        f.puts "  e.translations_synced_at = #{example.translations_synced_at.inspect}"
        f.puts "end"
        f.puts ""
      end
      
      # Export SourceAttributions
      f.puts "# Source Attributions"
      SourceAttribution.find_each do |attribution|
        f.puts "SourceAttribution.find_or_create_by("
        f.puts "  training_source_id: #{attribution.training_source_id},"
        f.puts "  sourceable_type: #{attribution.sourceable_type.inspect},"
        f.puts "  sourceable_id: #{attribution.sourceable_id}"
        f.puts ") do |sa|"
        f.puts "  sa.reference = #{attribution.reference.inspect}"
        f.puts "  sa.notes = #{attribution.notes.inspect}"
        f.puts "end"
        f.puts ""
      end
      
      # Export ActiveStorage Blobs and Attachments for TrainingSources
      f.puts "# ActiveStorage Blobs for TrainingSources"
      TrainingSource.find_each do |source|
        source.source_files.each do |file|
          blob = file.blob
          f.puts "blob_#{blob.id} = ActiveStorage::Blob.find_or_create_by(key: #{blob.key.inspect}) do |b|"
          f.puts "  b.filename = #{blob.filename.to_s.inspect}"
          f.puts "  b.content_type = #{blob.content_type.inspect}"
          f.puts "  b.metadata = #{blob.metadata.inspect}"
          f.puts "  b.byte_size = #{blob.byte_size}"
          f.puts "  b.checksum = #{blob.checksum.inspect}"
          f.puts "  b.service_name = 'local'"
          f.puts "end"
          f.puts ""
          f.puts "unless source_#{source.id}.source_files.where(id: blob_#{blob.id}.attachments.first&.id).exists?"
          f.puts "  source_#{source.id}.source_files.attach(blob_#{blob.id})"
          f.puts "end"
          f.puts ""
        end
      end
      
      f.puts "puts '✅ Training data imported successfully!'"
    end
    
    puts "✅ Training data exported to: #{output_file}"
    puts "📊 Statistics:"
    puts "   - TrainingSources: #{TrainingSource.count}"
    puts "   - TrainingConcepts: #{TrainingConcept.count}"
    puts "   - TrainingExamples: #{TrainingExample.count}"
    puts "   - SourceAttributions: #{SourceAttribution.count}"
    puts ""
    puts "To import in production:"
    puts "  RAILS_ENV=production rails runner db/seeds/training_data.rb"
  end
  
  desc "Import training data from db/seeds/training_data.rb"
  task import: :environment do
    file_path = Rails.root.join('db/seeds/training_data.rb')
    
    if File.exist?(file_path)
      puts "Importing training data from #{file_path}..."
      load file_path
    else
      puts "❌ File not found: #{file_path}"
      puts "Run 'rails training_data:export' first!"
    end
  end
  
  desc "Copy ActiveStorage files for training sources"
  task copy_storage: :environment do
    require 'fileutils'
    
    storage_path = Rails.root.join('storage')
    backup_path = Rails.root.join('storage_backup', Time.current.strftime('%Y%m%d_%H%M%S'))
    
    FileUtils.mkdir_p(backup_path)
    FileUtils.cp_r(storage_path, backup_path)
    
    puts "✅ Storage copied to: #{backup_path}"
    puts ""
    puts "To restore in production:"
    puts "  1. Copy the storage_backup folder to production server"
    puts "  2. rsync -av storage_backup/TIMESTAMP/storage/ /path/to/production/storage/"
  end
end
