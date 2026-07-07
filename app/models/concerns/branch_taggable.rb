# frozen_string_literal: true

# Leitet branch_id aus discipline.root ab (wenn dieser ein Branch ist) — analog region_id/RegionTaggable.
# Bewusst SCHLANK: nur die Live-Spalte, KEINE Version-/PaperTrail-Tagging-Maschinerie.
# Backfill globaler Records (id<MIN_ID, LocalProtector) via update_all in lib/tasks/branch_taggings.rake.
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
