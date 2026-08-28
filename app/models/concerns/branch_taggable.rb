# frozen_string_literal: true

# Leitet branch_id aus discipline.root ab (wenn dieser ein Branch ist) — analog region_id/RegionTaggable.
# Bewusst SCHLANK: nur die Live-Spalte, KEINE Version-/PaperTrail-Tagging-Maschinerie.
# Fuellt die Live-Spalte nur bei lokalen/neuen Saves: gesyncte Global-Records (id<MIN_ID) kommen per
# update_columns an (umgeht before_save), LocalProtector sperrt lokale Modifikation -> branch_id bleibt
# dort NULL (ein Backfill existiert nicht). Die Scope-Facette "branch" filtert deshalb NICHT ueber die
# Spalte, sondern loest zur Query-Zeit ueber den Disziplin-Teilbaum auf
# (SearchService#apply_scope -> Branch.discipline_ids_for, search_service.rb:85-92).
module BranchTaggable
  extend ActiveSupport::Concern

  included do
    before_save :set_branch_id, if: -> { will_save_change_to_discipline_id? || branch_id.nil? }
  end

  # Branch-Root der Disziplin (Pool/Snooker/Karambol/Kegel) oder nil, wenn (noch) nicht unter
  # einem Branch wurzelnd (z.B. 10-Ball bis zum Authority-Baum-Fix).
  def find_associated_branch_id
    root = discipline&.root
    root.is_a?(Branch) ? root.id : nil
  end

  def set_branch_id
    self.branch_id = find_associated_branch_id
  end
end
