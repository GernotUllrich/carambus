namespace :branch_taggings do
  desc "Backfill branch_id (Branch-Root der Disziplin) für Tournament + League"
  task update_all_branch_id: :environment do
    # Disziplin-id => Branch-Root-id (oder nil, wenn root kein Branch ist)
    branch_by_discipline = Discipline.all.each_with_object({}) do |d, h|
      root = d.root
      h[d.id] = root.is_a?(Branch) ? root.id : nil
    end

    # update_all bypassed LocalProtector (keine Callbacks) — nötig für globale Records (id<MIN_ID).
    [Tournament, League].each do |model|
      model.update_all(branch_id: nil)
      branch_by_discipline.each do |discipline_id, branch_id|
        next if branch_id.nil?
        model.where(discipline_id: discipline_id).update_all(branch_id: branch_id)
      end
      classified = model.where.not(branch_id: nil).count
      unclassified = model.where(branch_id: nil).count
      puts "#{model.name}: #{classified} klassifiziert, #{unclassified} nil"
    end
  end
end
