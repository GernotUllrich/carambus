# == Schema Information
#
# Table name: registration_ccs
#
#  id                      :bigint           not null, primary key
#  status                  :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  player_id               :integer
#  registration_list_cc_id :integer
#
# Indexes
#
#  index_registration_ccs_on_player_id_and_registration_list_cc_id  (player_id,registration_list_cc_id) UNIQUE
#
class RegistrationCc < ApplicationRecord
  include LocalProtector
  belongs_to :player
  belongs_to :registration_list_cc

  validates :player_id, uniqueness: { scope: :registration_list_cc_id }

  def self.create_from_ba(tournament, opts)
    region = tournament.organizer
    region_cc = region.region_cc
    registration_list_cc = RegistrationListCc.where(
      name: tournament.title,
      context: region.shortname.downcase,
      discipline_id: tournament.discipline_id,
      season_id: tournament.season_id
    ).first
    registration_list_cc.destroy if registration_list_cc.present?
    branch_cc_id = tournament.discipline.andand.root.andand.branch_cc.andand.cc_id
    cat_scope = "Unisex"
    cat_scope = "Damen" if /Damen/.match?(tournament.title)
    cat_scope = "Herren" if /Herren/.match?(tournament.title)
    cat_scope = "Junioren" if /Junioren/.match?(tournament.title)
    cat_scope = "Junioren" if /Jugend/.match?(tournament.title)
    cat_scope = "Kegel" if tournament.discipline.andand.root.andand.branch_cc.name == "Kegel"
    begin
      args = {
        fedId: region.cc_id,
        branchId: branch_cc_id,
        disciplinId: tournament.discipline.discipline_cc.cc_id,
        season: opts[:season_name],
        catId: CategoryCc.where("name ilike '%#{cat_scope}%'").where(branch_cc_id: tournament.discipline.root.branch_cc.id).first.andand.cc_id,
        meldelistenName: tournament.title,
        meldeschluss: (tournament.date - 14.days).strftime("%d.%m.%Y"),
        stichtag: "01.01.#{tournament.date.year}"
      }
    rescue Exception => e
      Rails.logger.error "Error: #{e} Tournament[#{tournament.id}]"
      return
    end
    _, doc = region_cc.post_cc("showMeldelistenList", args, opts)
    found = false
    options = doc.css("select[name=\"meldelisteId\"] > option")
    options.each do |option|
      if option.text.strip == tournament.title
        found = true
        break
      end
    end
    unless found
      args = {
        fedId: region.cc_id,
        branchId: branch_cc_id,
        selectedDisciplinId: tournament.discipline.discipline_cc.cc_id,
        season: opts[:season_name],
        selectedCatId: CategoryCc.where("name ilike '%#{cat_scope}%'").where(branch_cc_id: tournament.discipline.root.branch_cc.id).first.andand.cc_id,
        meldelistenName: tournament.title,
        meldeschluss: (tournament.date - 14.days).strftime("%d.%m.%Y"),
        stichtag: "01.01.#{tournament.date.year}",
        save: ""
      }
      region_cc.post_cc("createMeldelisteSave", args, opts)
    end
    args = {
      fedId: region.cc_id,
      branchId: branch_cc_id,
      disciplinId: tournament.discipline.discipline_cc.cc_id,
      season: opts[:season_name],
      catId: CategoryCc.where("name ilike '%#{cat_scope}%'").where(branch_cc_id: tournament.discipline.root.branch_cc.id).first.andand.cc_id,
      meldelistenName: tournament.title,
      meldeschluss: (tournament.date - 14.days).strftime("%d.%m.%Y"),
      stichtag: "01.01.#{tournament.date.year}"
    }
    _, doc = region_cc.post_cc("showMeldelistenList", args, opts)
    found = false
    options = doc.css("select[name=\"meldelisteId\"] > option")
    options.each do |option|
      if option.text.strip == tournament.title
        found = true
        break
      end
    end
    return if found

    raise "Error: Synchronization failed"
  end
end
