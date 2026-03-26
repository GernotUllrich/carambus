# Discipline Hierarchy Restructuring
# 
# This seed restructures the discipline hierarchy to add intermediate
# table-independent disciplines between Karambol and table-specific disciplines.
#
# Old: Karambol > Dreiband klein
# New: Karambol > Dreiband > Dreiband klein
#
# This should be run on the API server to propagate changes to all local servers.

puts "="*60
puts "Restructuring Discipline Hierarchy"
puts "="*60
puts ""

# Find or create the Karambol super discipline
karambol = Discipline.find_or_create_by!(name: "Karambol") do |d|
  d.super_discipline_id = nil
  d.table_kind_id = nil
end

puts "✓ Found/Created: Karambol (ID: #{karambol.id})"
puts ""

# Define the main discipline categories with their child discipline patterns
discipline_mappings = {
  "Dreiband" => {
    pattern: "Dreiband",
    children: ["Dreiband groß", "Dreiband halb", "Dreiband klein", "Dreiband Doppel (kl)"]
  },
  "Cadre" => {
    pattern: "Cadre",
    children: ["Cadre 35/2", "Cadre 38/2", "Cadre 47/1", "Cadre 47/2", 
               "Cadre 52/2", "Cadre 57/2", "Cadre 71/2"]
  },
  "Einband" => {
    pattern: "Einband",
    children: ["Einband groß", "Einband halb", "Einband klein"]
  },
  "Freie Partie" => {
    pattern: "Freie Partie",
    children: ["Freie Partie groß", "Freie Partie klein"]
  }
}

# Process each main discipline category
discipline_mappings.each do |discipline_name, config|
  puts "Processing: #{discipline_name}"
  puts "-" * 40
  
  # Check for duplicates first
  existing = Discipline.where(name: discipline_name, table_kind_id: nil)
  if existing.count > 1
    puts "  ⚠ Found #{existing.count} duplicates, cleaning up..."
    keep = existing.order(:id).first
    duplicates = existing.where.not(id: keep.id)
    
    duplicates.each do |dup|
      # Reassign children
      Discipline.where(super_discipline_id: dup.id).update_all(super_discipline_id: keep.id)
      # Reassign training concepts
      TrainingConceptDiscipline.where(discipline_id: dup.id).update_all(discipline_id: keep.id)
      dup.destroy
      puts "    Removed duplicate ID #{dup.id}"
    end
    
    intermediate_discipline = keep
  else
    # Find or create the intermediate discipline (table-independent)
    intermediate_discipline = Discipline.find_or_create_by!(
      name: discipline_name,
      table_kind_id: nil
    ) do |d|
      d.super_discipline_id = karambol.id
    end
  end
  
  # If it already exists but has wrong parent, update it
  if intermediate_discipline.super_discipline_id != karambol.id
    intermediate_discipline.update!(super_discipline_id: karambol.id)
  end
  
  puts "  ✓ Created/Updated: #{discipline_name} (ID: #{intermediate_discipline.id})"
  puts "    Parent: #{intermediate_discipline.super_discipline&.name || 'None'}"
  puts "    TableKind: #{intermediate_discipline.table_kind&.name || 'None (table-independent)'}"
  
  # Find and reassign child disciplines
  config[:children].each do |child_name|
    child = Discipline.find_by(name: child_name)
    
    if child
      old_parent = child.super_discipline&.name || 'None'
      
      # Update parent if needed
      if child.super_discipline_id != intermediate_discipline.id
        child.update!(super_discipline_id: intermediate_discipline.id)
        puts "    ├─ Reassigned: #{child.name} (ID: #{child.id})"
        puts "    │  Old parent: #{old_parent} → New parent: #{intermediate_discipline.name}"
        puts "    │  TableKind: #{child.table_kind&.name || 'None'}"
      else
        puts "    ├─ Already correct: #{child.name} (ID: #{child.id})"
      end
    else
      puts "    ⚠ Not found: #{child_name}"
    end
  end
  
  puts ""
end

# Special case: Handle "Dreiband Doppel (kl)" which should be under "Dreiband klein"
dreiband_doppel = Discipline.find_by(name: "Dreiband Doppel (kl)")
dreiband_klein = Discipline.find_by(name: "Dreiband klein")

if dreiband_doppel && dreiband_klein
  if dreiband_doppel.super_discipline_id != dreiband_klein.id
    dreiband_doppel.update!(super_discipline_id: dreiband_klein.id)
    puts "Special case:"
    puts "  ✓ Set 'Dreiband Doppel (kl)' as child of 'Dreiband klein'"
    puts ""
  end
end

puts "="*60
puts "Hierarchy Restructuring Complete!"
puts "="*60
puts ""

# Display the new structure
puts "New Hierarchy:"
puts ""
puts "Karambol"

["Dreiband", "Cadre", "Einband", "Freie Partie"].each do |main_name|
  main_disc = Discipline.find_by(name: main_name)
  next unless main_disc
  
  puts "  ├─ #{main_name}"
  
  children = Discipline.where(super_discipline_id: main_disc.id).order(:name)
  children.each_with_index do |child, index|
    is_last = (index == children.count - 1)
    prefix = is_last ? "└─" : "├─"
    puts "  │  #{prefix} #{child.name} (#{child.table_kind&.name || 'no table'})"
    
    # Show grandchildren
    grandchildren = Discipline.where(super_discipline_id: child.id).order(:name)
    grandchildren.each_with_index do |gc, gc_index|
      gc_is_last = (gc_index == grandchildren.count - 1)
      gc_prefix = gc_is_last ? "└─" : "├─"
      indent = is_last ? "   " : "│  "
      puts "  │  #{indent}  #{gc_prefix} #{gc.name}"
    end
  end
end

puts ""
puts "✓ Done!"
