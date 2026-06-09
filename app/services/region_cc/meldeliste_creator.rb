# frozen_string_literal: true

# Erstellt eine Meldeliste auf der CC-Seite (createMeldelisteSave) für ein
# Carambus-Tournament, falls noch keine existiert. Keine DB-Writes — Side-Effect
# nur CC-seitig. Wird vom RegionCc.synchronize_tournament_structure-Pfad pro
# Tournament aufgerufen.
#
# Plan 23-01 T1b: Extrahiert aus dem gelöschten RegistrationCc-Model. Methodenname
# war misleading (`create_from_ba`) — die Methode hat nie RegistrationCc-Records
# erzeugt, sondern eine CC-Meldeliste über die CC-HTTP-API angelegt.
class RegionCc::MeldelisteCreator < ApplicationService
  def initialize(options = {})
    @tournament = options.fetch(:tournament)
    @opts = options.except(:tournament)
  end

  def call
    region = @tournament.organizer
    region_cc = region.region_cc
    branch_cc_id = @tournament.discipline.andand.root.andand.branch_cc.andand.cc_id
    cat_scope = compute_cat_scope

    args = build_show_args(region, branch_cc_id, cat_scope)
    return unless args

    _, doc = region_cc.post_cc("showMeldelistenList", args, @opts)
    return if meldeliste_present?(doc)

    region_cc.post_cc("createMeldelisteSave", build_save_args(region, branch_cc_id, cat_scope), @opts)

    _, verify_doc = region_cc.post_cc("showMeldelistenList", args, @opts)
    return if meldeliste_present?(verify_doc)

    raise "Error: Synchronization failed"
  end

  private

  def compute_cat_scope
    title = @tournament.title.to_s
    branch_name = @tournament.discipline.andand.root.andand.branch_cc.andand.name
    return "Kegel" if branch_name == "Kegel"
    return "Damen" if /Damen/.match?(title)
    return "Herren" if /Herren/.match?(title)
    return "Junioren" if /Junioren|Jugend/.match?(title)
    "Unisex"
  end

  def cat_id(branch_cc_id_carambus, cat_scope)
    return nil if branch_cc_id_carambus.nil?
    CategoryCc.where("name ilike '%#{cat_scope}%'")
      .where(branch_cc_id: branch_cc_id_carambus)
      .first&.cc_id
  end

  def build_show_args(region, branch_cc_id, cat_scope)
    {
      fedId: region.cc_id,
      branchId: branch_cc_id,
      disciplinId: @tournament.discipline.discipline_cc.cc_id,
      season: @opts[:season_name],
      catId: cat_id(@tournament.discipline.root.branch_cc.id, cat_scope),
      meldelistenName: @tournament.title,
      meldeschluss: (@tournament.date - 14.days).strftime("%d.%m.%Y"),
      stichtag: "01.01.#{@tournament.date.year}"
    }
  rescue => e
    Rails.logger.error "Error: #{e} Tournament[#{@tournament.id}]"
    nil
  end

  def build_save_args(region, branch_cc_id, cat_scope)
    {
      fedId: region.cc_id,
      branchId: branch_cc_id,
      selectedDisciplinId: @tournament.discipline.discipline_cc.cc_id,
      season: @opts[:season_name],
      selectedCatId: cat_id(@tournament.discipline.root.branch_cc.id, cat_scope),
      meldelistenName: @tournament.title,
      meldeschluss: (@tournament.date - 14.days).strftime("%d.%m.%Y"),
      stichtag: "01.01.#{@tournament.date.year}",
      save: ""
    }
  end

  def meldeliste_present?(doc)
    return false unless doc
    doc.css('select[name="meldelisteId"] > option').any? { |opt| opt.text.strip == @tournament.title }
  end
end
