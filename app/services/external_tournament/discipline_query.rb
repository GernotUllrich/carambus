# frozen_string_literal: true

module ExternalTournament
  # Plan 20-01 (v0.6 F3): Disziplin-Discovery fuer die externe Turnier-App.
  # Liefert die in der Region relevanten offiziellen Disziplinen als Selektor-Substrat
  # (exakte Namen, die 1:1 in player_rankings (F1) und start_game matchen) inkl. der
  # vollstaendigen DisciplineTournamentPlan-Matrix (points/innings/players/player_class)
  # und der referenzierten TournamentPlan-Definitionen. Read-only, keine Seiteneffekte.
  # Referenz: HANDOFF-to-carambus-setup-discovery.md (Endpoint 1).
  #
  # Decisions (Discuss 2026-05-23):
  #   D-20-01-A Region-Relevanz: nur Disziplinen mit PlayerRankings ODER Tournaments in der
  #     Region. Disziplinen sind global (kein region_id); der Selektor zeigt aber nur regional
  #     Genutztes. Die DTP-/Plan-Matrix einer gelisteten Disziplin wird global vollstaendig geliefert.
  #   D-20-01-B player_classes inline pro Disziplin (shortnames), sortiert nach PLAYER_CLASS_ORDER.
  #   D-20-01-C table_kind nur als Feld (kein Server-Filter-Param in v1).
  #   D-20-01-D normalisiertes Payload: Top-Level tournament_plans-Dict (key=Plan-Name) +
  #     pro Disziplin parameters[] (plan per Name referenziert), keine Plan-Duplikate.
  #   D-20-01-E volle Plan-Felder inkl. Executor; Text-Felder (rulesystem/executor_params/
  #     Beschreibungen) ROH als gespeicherter String durchgereicht (kein Parsen).
  class DisciplineQuery
    Result = Struct.new(:disciplines, :tournament_plans, keyword_init: true)

    # Player-Klassen-Ordnung (worst -> best) aus dem Discipline-Modell wiederverwenden.
    PLAYER_CLASS_ORDER = Discipline::PLAYER_CLASS_ORDER

    def self.call(region:)
      return Result.new(disciplines: [], tournament_plans: {}) if region.blank?

      discipline_ids = region_discipline_ids(region)
      disciplines = Discipline
        .where(id: discipline_ids)
        .includes(:table_kind, :super_discipline, :player_classes, discipline_tournament_plans: :tournament_plan)
        .to_a

      Result.new(
        disciplines: disciplines
          .sort_by { |d| [d.table_kind&.name.to_s, d.name.to_s] }
          .map { |d| serialize_discipline(d) },
        tournament_plans: tournament_plans_for(discipline_ids)
      )
    end

    # D-20-01-A: Disziplin-IDs mit Bezug zur Region (PlayerRankings ODER Tournaments).
    def self.region_discipline_ids(region)
      ranking_ids = PlayerRanking.where(region_id: region.id).distinct.pluck(:discipline_id)
      tournament_ids = Tournament.where(region_id: region.id).distinct.pluck(:discipline_id)
      (ranking_ids + tournament_ids).compact.uniq
    end

    def self.serialize_discipline(discipline)
      {
        name: discipline.name,
        synonyms: synonyms_without_name(discipline),
        table_kind: discipline.table_kind&.name,
        super_discipline: discipline.super_discipline&.name,
        player_classes: sorted_player_classes(discipline),
        parameters: parameters_for(discipline)
      }
    end

    # D-15-02: synonyms ist newline-separiert + enthaelt den Namen selbst -> Namen subtrahieren.
    def self.synonyms_without_name(discipline)
      return [] if discipline.synonyms.blank?
      (discipline.synonyms.split("\n").map(&:strip).reject(&:blank?) - [discipline.name])
    end

    # D-20-01-B: player_class-Shortnames nach PLAYER_CLASS_ORDER; Unbekannte ans Ende (alpha).
    def self.sorted_player_classes(discipline)
      discipline.player_classes.map(&:shortname).compact.uniq.sort_by do |shortname|
        idx = PLAYER_CLASS_ORDER.index(shortname)
        idx ? [0, idx, ""] : [1, 0, shortname.to_s]
      end
    end

    # D-20-01-D: DTP-Matrix-Zeilen der Disziplin; tournament_plan per Name referenziert.
    def self.parameters_for(discipline)
      discipline.discipline_tournament_plans.map do |dtp|
        {
          tournament_plan: dtp.tournament_plan&.name,
          players: dtp.players,
          player_class: dtp.player_class,
          points: dtp.points,
          innings: dtp.innings
        }
      end.sort_by { |row| [row[:tournament_plan].to_s, row[:players].to_i, row[:player_class].to_s] }
    end

    # D-20-01-D/E: normalisiertes Dict aller von den gelisteten Disziplinen referenzierten
    # TournamentPlans (key = name), volle Felder inkl. Executor (Text-Felder roh).
    def self.tournament_plans_for(discipline_ids)
      plan_ids = DisciplineTournamentPlan
        .where(discipline_id: discipline_ids)
        .distinct
        .pluck(:tournament_plan_id)
        .compact
      TournamentPlan.where(id: plan_ids).each_with_object({}) do |plan, acc|
        next if plan.name.blank?
        acc[plan.name] = {
          players: plan.players,
          tables: plan.tables,
          ngroups: plan.ngroups,
          nrepeats: plan.nrepeats,
          rulesystem: plan.rulesystem,
          executor_class: plan.executor_class,
          executor_params: plan.executor_params,
          more_description: plan.more_description,
          even_more_description: plan.even_more_description
        }
      end
    end
  end
end
