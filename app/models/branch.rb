# == Schema Information
#
# Table name: disciplines
#
#  id                  :bigint           not null, primary key
#  data                :text
#  name                :string
#  synonyms            :text
#  team_size           :integer
#  type                :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  super_discipline_id :integer
#  table_kind_id       :integer
#
# Indexes
#
#  index_disciplines_on_foreign_keys            (name,table_kind_id) UNIQUE
#  index_disciplines_on_name_and_table_kind_id  (name,table_kind_id) UNIQUE
#
class Branch < Discipline
  # Liefert alle Disziplin-ids, deren Baum-Wurzel (discipline.root) diese Branch ist —
  # inkl. der Branch-id selbst. Ersetzt die (bei gesyncten Global-Records leere)
  # branch_id-Spalte für die Scope-Band-Branch-Facette (SB-2, 17-03): der Version-Apply
  # umgeht via update_columns den BranchTaggable-before_save, LocalProtector sperrt Re-Save
  # → branch_id bleibt NULL. Deshalb hier die Auflösung zur Query-Zeit über discipline.root.
  #
  # Einmalige In-Memory-Auflösung des gesamten Disziplin-Baums (ein pluck, kein N+1 root-Walk),
  # prozessweit memoisiert. Der Baum ändert sich nur per Sync/Scrape (selten) — Cache wird bei
  # Code-Reload (dev) bzw. Deploy/Neustart (prod) frisch aufgebaut; .reset_discipline_ids_cache!
  # erzwingt Neuberechnung.
  def self.discipline_ids_for(branch_id)
    id = branch_id.to_i
    return [] if id.zero?

    ids_by_root.fetch(id, [id])
  end

  def self.ids_by_root
    @ids_by_root ||= begin
      parent = Discipline.pluck(:id, :super_discipline_id).to_h
      groups = Hash.new { |h, k| h[k] = [] }
      parent.each_key do |disc_id|
        cursor = disc_id
        seen = {}
        while (up = parent[cursor]) && !seen[cursor]
          seen[cursor] = true
          cursor = up
        end
        groups[cursor] << disc_id
      end
      groups
    end
  end

  def self.reset_discipline_ids_cache!
    @ids_by_root = nil
  end
end
