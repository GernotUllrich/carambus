# frozen_string_literal: true

# cc_check_player_discipline_experience — Heuristik: Hat dieser Spieler in
# dieser Disziplin schon mal gespielt?
#
# Walking-Skeleton-Use-Case (Phase 5): Vor dem Anmelden eines Spielers stellt
# Claude Desktop die Plausibilitäts-Frage „Bist Du sicher? Joshua hat noch nie
# an einem Eurokegel-Turnier teilgenommen — trotzdem eintragen?"
#
# Heuristik (zwei Signale):
#   (a) PlayerRanking-Existenz für (player, discipline, region)
#   (b) GameParticipation in einem Game über Tournament(.discipline_id) ODER
#       Tournament.league.discipline_id
#
# Begründung Backup via GameParticipation: Rankings werden am Saisonende
# erstellt — kürzlich-gespielt-aber-noch-nicht-gerankt würde sonst falsch als
# „nie gespielt" markiert. (CONTEXT.md Phase 5 Decision.)
#
# Output ist explizit „best effort" für v0.1: Trainings-Games ohne Tournament/
# League-Verknüpfung zählen NICHT als experienced. Das ist akzeptiert, kann
# in v0.2 verfeinert werden.

module McpServer
  module Tools
    class CheckPlayerDisciplineExperience < BaseTool
      tool_name "cc_check_player_discipline_experience"
      description "Heuristik: Hat der Spieler in dieser Disziplin schon einmal gespielt? " \
                  "Prüft (a) PlayerRanking-Existenz und (b) GameParticipation in Games dieser " \
                  "Disziplin via Tournament/League. experienced:false bedeutet 'wahrscheinlich " \
                  "Erstantritt' — ideal als Plausibilitäts-Check vor der Anmeldung. " \
                  "Trainings-Games ohne Tournament/League-Bezug zählen NICHT als Erfahrung."
      input_schema(
        properties: {
          player_id: {type: "integer", description: "Carambus Player.id (NICHT cc_id)."},
          discipline_id: {type: "integer", description: "Carambus Discipline.id."},
          shortname: {type: "string", description: "Region-shortname (z.B. 'NBV'). Optional — Default via CC_REGION/Setting 'context'."}
        },
        required: ["player_id", "discipline_id"]
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(player_id: nil, discipline_id: nil, shortname: nil, server_context: nil)
        return error("Missing required parameter: `player_id`") if player_id.blank?
        return error("Missing required parameter: `discipline_id`") if discipline_id.blank?

        player = Player.find_by(id: player_id)
        return error("Player not found: id=#{player_id}") if player.nil?

        discipline = Discipline.find_by(id: discipline_id)
        return error("Discipline not found: id=#{discipline_id}") if discipline.nil?

        region = resolve_region(shortname: shortname)
        return error("Region not found. Provide shortname, or set CC_REGION/Setting 'context'.") if region.nil?

        has_ranking = PlayerRanking.where(
          player_id: player.id,
          discipline_id: discipline.id,
          region_id: region.id
        ).exists?

        # GameParticipation via direkter Tournament-Disziplin
        has_participation_via_tournament = GameParticipation
          .joins(game: :tournament)
          .where(player_id: player.id)
          .where(tournaments: {discipline_id: discipline.id})
          .exists?

        # GameParticipation via League-Disziplin (Tournament.league.discipline_id)
        has_participation_via_league = GameParticipation
          .joins(game: {tournament: :league})
          .where(player_id: player.id)
          .where(leagues: {discipline_id: discipline.id})
          .exists?

        has_participation = has_participation_via_tournament || has_participation_via_league
        experienced = has_ranking || has_participation

        reason = build_reason(experienced, has_ranking, has_participation, discipline.name)

        text(JSON.generate(
          experienced: experienced,
          signals: {
            has_ranking: has_ranking,
            has_game_participation: has_participation,
            has_participation_via_tournament: has_participation_via_tournament,
            has_participation_via_league: has_participation_via_league
          },
          reason: reason,
          meta: {
            region: region.shortname,
            player_id: player.id,
            player_fl_name: player.fl_name,
            discipline_id: discipline.id,
            discipline_name: discipline.name
          }
        ))
      end

      def self.build_reason(experienced, has_ranking, has_participation, discipline_name)
        if experienced
          if has_ranking && has_participation
            "Spieler hat aktuelles PlayerRanking UND GameParticipation in '#{discipline_name}' — klar erfahren."
          elsif has_ranking
            "Spieler hat aktuelles PlayerRanking in '#{discipline_name}'."
          else
            "Spieler hat bereits in '#{discipline_name}' gespielt (GameParticipation vorhanden, noch kein Ranking — z.B. neue Saison)."
          end
        else
          "Spieler hat in '#{discipline_name}' weder Ranking noch Spielhistorie — wahrscheinlich Erstantritt. Plausibilitäts-Rückfrage empfohlen."
        end
      end

      def self.resolve_region(shortname:)
        if shortname.present?
          Region.find_by(shortname: shortname.to_s.upcase)
        else
          fallback_id = default_fed_id
          fallback_id ? RegionCc.find_by(cc_id: fallback_id)&.region : nil
        end
      end
    end
  end
end
