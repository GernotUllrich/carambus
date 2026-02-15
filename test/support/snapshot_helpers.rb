# frozen_string_literal: true

module SnapshotHelpers
  # Helper to save a snapshot of current data for comparison
  def save_snapshot(name, data)
    snapshot_dir = Rails.root.join('test', 'snapshots', 'data')
    FileUtils.mkdir_p(snapshot_dir)
    
    file_path = snapshot_dir.join("#{name}.yml")
    File.write(file_path, YAML.dump(data))
    
    data
  end
  
  # Helper to load a snapshot
  def load_snapshot(name)
    file_path = Rails.root.join('test', 'snapshots', 'data', "#{name}.yml")
    return nil unless File.exist?(file_path)
    
    YAML.load_file(file_path)
  end
  
  # Helper to assert data matches snapshot
  def assert_matches_snapshot(name, data)
    snapshot = load_snapshot(name)
    
    if snapshot.nil?
      # First run - save snapshot
      save_snapshot(name, data)
      skip "Snapshot #{name} created. Run tests again to verify."
    else
      # Compare with snapshot
      assert_equal snapshot, data, "Data should match snapshot #{name}"
    end
  end
  
  # Helper to update snapshot (use when intentional change)
  def update_snapshot(name, data)
    save_snapshot(name, data)
  end
  
  # Helper to capture model attributes for snapshot
  def snapshot_attributes(record, *attrs)
    attrs = record.attribute_names if attrs.empty?
    attrs.index_with { |attr| record.send(attr) }
  end
  
  # Helper to compare HTML structure (ignoring content changes)
  def assert_html_structure_unchanged(cassette_name)
    VCR.use_cassette(cassette_name) do
      doc = yield # Block should return Nokogiri document
      
      # Extract structure (tags, classes, IDs) without text content
      structure = extract_html_structure(doc)
      assert_matches_snapshot("#{cassette_name}_structure", structure)
    end
  end
  
  private
  
  def extract_html_structure(doc)
    # Recursively extract HTML structure
    return nil if doc.nil?
    
    {
      name: doc.name,
      classes: doc['class']&.split,
      id: doc['id'],
      children: doc.children.select { |c| c.element? }.map { |c| extract_html_structure(c) }
    }
  end
end
