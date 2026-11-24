# frozen_string_literal: true

# Löscht LeagueTeams, deren Liga nicht mehr existiert und an denen nichts mehr hängt.
#
# Entstehung: `League has_many :league_teams` hat kein `dependent:` — ein League#destroy lässt die Teams
# stehen. Auf der Authority waren das 2026-11-24 3 378 Teams aus dem BillardArea-Import vom April 2022
# (452 gelöschte Ligen, IDs 1756–5496), alle ohne Seedings, Partien, LeagueTeamCc oder Versionen.
#
# Gelöscht wird nur, was frei ist: keine Seedings, keine Partie mit dem Team als A, B, Gastgeber oder
# Nichtantritt, kein LeagueTeamCc. Anderes bleibt und wird als blockiert gemeldet.
# Per destroy (PaperTrail → Sync). Ohne Liga ist die Version ohne region_id und erreicht jeden Server;
# dort ist es ein `delete` auf einen evtl. fehlenden Record, also harmlos. Broadcast-frei, je Stapel eine
# Transaktion.
class League::OrphanTeamPurger
  BATCH = 500

  attr_reader :orphans, :blocked, :deleted, :errors

  def initialize(armed: false)
    @armed = armed
    @deleted = 0
    @errors = []
  end

  def call
    all = LeagueTeam.where.not(League.where("leagues.id = league_teams.league_id").arel.exists)
    free = all
      .where.not(Seeding.where("seedings.league_team_id = league_teams.id").arel.exists)
      .where.not(Party.where("league_teams.id IN (parties.league_team_a_id, parties.league_team_b_id, " \
                             "parties.host_league_team_id, parties.no_show_team_id)").arel.exists)
      .where.not(LeagueTeamCc.where("league_team_ccs.league_team_id = league_teams.id").arel.exists)
    @orphans = free.order(:id).ids
    @blocked = all.where.not(id: @orphans).order(:id).ids
    purge if @armed
    self
  end

  private

  def purge
    LeagueTeam.skip_cable_ready_updates do
      @orphans.each_slice(BATCH) do |ids|
        ActiveRecord::Base.transaction { LeagueTeam.where(id: ids).find_each(&:destroy!) }
        @deleted += ids.size
      rescue => e
        @errors << "Stapel ab LeagueTeam[#{ids.first}]: #{e.class}: #{e.message}"
      end
    end
  end
end
