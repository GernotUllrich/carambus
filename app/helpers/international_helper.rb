# frozen_string_literal: true

module InternationalHelper
  # Discipline groups with IDs for hierarchical filtering
  DISCIPLINE_GROUPS = {
    '3-Cushion (Dreiband)' => ['Dreiband halb', 'Dreiband groß', 'Dreiband klein'],
    '1-Cushion (Einband)' => ['Einband halb', 'Einband groß', 'Einband klein'],
    'Straight Rail (Freie Partie)' => ['Freie Partie klein', 'Freie Partie groß'],
    'Cadre / Balkline' => ['Cadre 35/2', 'Cadre 47/2', 'Cadre 52/2', 'Cadre 57/2', 'Cadre 71/2'],
    '5-Pin Billards' => ['5-Pin Billards'],
    'Pool Billard' => ['Pool'],
    'Snooker' => ['Snooker']
  }.freeze
  
  # Get all discipline IDs for a group name
  def self.discipline_ids_for_group(group_name)
    discipline_names = DISCIPLINE_GROUPS[group_name]
    return [] if discipline_names.blank?
    
    Discipline.where(name: discipline_names).pluck(:id)
  end
  
  # Grouped disciplines for select dropdown (flat list for now)
  def grouped_disciplines_for_select
    groups = []
    
    DISCIPLINE_GROUPS.each do |group_name, discipline_names|
      disciplines = Discipline.where(name: discipline_names).pluck(:name, :id)
      next if disciplines.empty?
      
      # Add group option (special value: "group:GroupName")
      group_value = "group:#{group_name}"
      groups << [group_name, [[group_name + ' (All)', group_value]]]
      
      # Add individual disciplines under group
      disciplines.each do |name, id|
        groups.last[1] << ["  → #{name}", id]
      end
    end
    
    groups
  end
  
  # Helper to get discipline IDs by names
  def discipline_ids_by_names(names)
    Discipline.where(name: names).pluck(:name, :id).map { |name, id| { name: name, id: id } }
  end
  
  # Badge colors for tournament types
  def tournament_type_badge_class(type)
    case type&.to_s
    when 'world_cup'
      'bg-purple-100 text-purple-800'
    when 'world_championship'
      'bg-red-100 text-red-800'
    when 'european_championship'
      'bg-blue-100 text-blue-800'
    when 'masters'
      'bg-yellow-100 text-yellow-800'
    when 'grand_prix'
      'bg-green-100 text-green-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
end
