# frozen_string_literal: true

module Bk2
  # Pure shot evaluator for BK2-Kombi discipline.
  #
  # Takes a shot_payload hash (shape: see phase 38.1 CONTEXT.md D-13)
  # and a state hash (shape: see D-14) and returns { scoring:, transitions: }.
  # No database writes. No mutation of input hashes.
  #
  # Foul convention: points_for_opponent holds the POSITIVE credit awarded to
  # the opposing player; foul_points holds the SIGNED published value per D-16
  # (e.g., -6 for wrong_ball). Rationale: downstream UI + CableReady broadcast
  # find it clearer to render "opponent +6" than "current -6 then credit moves".
  # AdvanceMatchState uses points_for_opponent directly to increment opponent score.
  #
  # Usage:
  #   Bk2::ScoreShot.call(shot_payload:, state:)
  #   Bk2::ScoreShot.call(shot_payload:, state:, rules: custom_rules)
  class ScoreShot
    DEFAULT_RULES = {
      scoring: {
        pin: 1,
        middle_pin_only_from_full_image: 2,
        true_carom: 1,
        false_carom_with_pin_or_passage: 1,
        passage: 1
      },
      foul_values: {
        wrong_ball: -6,
        no_object_ball_hit_with_band: -1,
        no_object_ball_hit_no_band: -2,
        premature_shot: -1,
        direct_play_on_pins: nil, # computed: -[1, fallen_pins].max (sentinel, never used directly)
        other: -1
      }
    }.freeze

    def self.call(shot_payload:, state:, rules: DEFAULT_RULES)
      new(shot_payload: shot_payload, state: state, rules: rules).call
    end

    def initialize(shot_payload:, state:, rules:)
      @shot_payload = shot_payload.deep_symbolize_keys
      @state = state.deep_symbolize_keys
      @rules = rules.deep_symbolize_keys
    end

    def call
      raw = calculate_raw_points
      foul_info = calculate_foul_points
      scoring = foul_info[:foul] ? apply_foul_scoring(raw, foul_info) : apply_positive_scoring(raw)
      transitions = calculate_transitions(scoring)
      {scoring: scoring, transitions: transitions}
    end

    private

    # Berechne Rohpunkte aus Pins, Carom und Passagen (BK2-KOMBI-RULES.md §Rohpunkte).
    def calculate_raw_points
      obs = @shot_payload[:observations]

      pin_points =
        if obs[:middle_pin_only] && @shot_payload.dig(:table_snapshot, :full_pin_image)
          @rules.dig(:scoring, :middle_pin_only_from_full_image).to_i
        else
          obs[:fallen_pins].to_i * @rules.dig(:scoring, :pin).to_i
        end

      carom_points = 0
      carom_points += @rules.dig(:scoring, :true_carom).to_i if obs[:true_carom]
      carom_points += @rules.dig(:scoring, :false_carom_with_pin_or_passage).to_i if obs[:false_carom]

      passage_points = obs[:passages].to_i * @rules.dig(:scoring, :passage).to_i

      {
        pin_points: pin_points,
        carom_points: carom_points,
        passage_points: passage_points,
        total: pin_points + carom_points + passage_points
      }
    end

    # Berechne Fehlerpunkte (SIGNED NEGATIVE) per D-16.
    #
    # SIGNED foul points. By Carambus convention (see ScoreShot class docstring),
    # foul_points is NEGATIVE: it's the published D-16 signed value. The opponent
    # receives `|foul_points|` as a positive credit via `points_for_opponent` in
    # `apply_foul_scoring`.
    #
    # DEFAULT_RULES stores `direct_play_on_pins: nil` as a sentinel meaning
    # "computed at call time". Do NOT fall back to `foul_values[:other]` for this
    # case — that would return -1 regardless of fallen_pins and break D-16.
    def calculate_foul_points
      return {foul: false} unless @shot_payload.dig(:observations, :foul)

      code = @shot_payload.dig(:observations, :foul_code) || :other
      obs = @shot_payload[:observations]

      foul_points =
        case code
        when :no_object_ball_hit
          # D-16 refinement: band_hit flag splits this foul into two sub-cases.
          if obs[:band_hit]
            @rules.dig(:foul_values, :no_object_ball_hit_with_band) # -1
          else
            @rules.dig(:foul_values, :no_object_ball_hit_no_band) # -2
          end
        when :direct_play_on_pins
          # D-16 computed rule: -max(1, fallen_pins). Always NEGATIVE.
          #   fallen_pins=0 → -1 (floor; asserted by test 10b — B3 checker fix)
          #   fallen_pins=3 → -3
          #   fallen_pins=5 → -5
          # DO NOT use @rules.dig(:foul_values, :direct_play_on_pins) directly —
          # the stored value is nil (sentinel). The signed arithmetic is inline.
          -[1, obs[:fallen_pins].to_i].max
        when :wrong_ball, :premature_shot
          @rules.dig(:foul_values, code) # -6 and -1 respectively, stored signed
        else
          # :other OR any unknown symbol (T-38.1-12 mitigation)
          @rules.dig(:foul_values, :other) || -1
        end

      {foul: true, foul_code: code, foul_points: foul_points.to_i}
    end

    # Wende positive Punktwertung an (kein Fehler).
    def apply_positive_scoring(raw)
      {
        foul: false,
        points_for_current_player: raw[:total],
        points_for_opponent: 0,
        raw_total: raw[:total],
        credited_total: raw[:total]
      }
    end

    # Wende Fehlerwertung an: Fehlermalus geht als Positiv-Kredit an den Gegner.
    # Carambus-Konvention: points_for_opponent ist eine POSITIVE Zahl (Kredit an Gegner).
    # foul_points ist NEGATIV (D-16-Signaturwert).
    #
    # Wichtig: Bei Fehlerstößen geht NICHT raw_total + |foul_points| an den Gegner.
    # Die gefallenen Kegel zählen bei einem Fehler NICHT als Rohpunkte für den Schützen —
    # der Fehlermalus (z.B. max(1, fallen_pins) für direct_play_on_pins) kodiert die
    # Konsequenz bereits vollständig. Daher: opponent_credit = |foul_points| only.
    # Belegt durch Plan-Test 10: direct_play_on_pins, fallen_pins=3 → points_for_opponent=3
    # (nicht 6 = raw(3) + penalty(3)).
    def apply_foul_scoring(raw, foul_info)
      # Opponent receives |foul_points| as a POSITIVE credit (foul penalty absolute value).
      opponent_credit = foul_info[:foul_points].abs
      {
        foul: true,
        foul_code: foul_info[:foul_code],
        foul_points: foul_info[:foul_points],
        points_for_current_player: 0,
        points_for_opponent: opponent_credit,
        raw_total: raw[:total],
        credited_total: opponent_credit
      }
    end

    # Berechne Zustandsübergänge: Bonusstoß, Spielerwechsel, verbleibende Schüsse.
    def calculate_transitions(scoring)
      phase = @state[:current_phase].to_s
      obs = @shot_payload[:observations]

      if phase == "direkter_zweikampf"
        calculate_direkter_zweikampf_transitions(scoring, obs)
      else
        calculate_serienspiel_transitions(scoring)
      end
    end

    # Phasenlogik für Direkter Zweikampf (BK2-KOMBI-RULES.md §Bonusstoß).
    def calculate_direkter_zweikampf_transitions(scoring, obs)
      bonus = !scoring[:foul] && bonus_shot?(obs)

      if bonus
        {
          bonus_shot_awarded: true,
          turn_ends: false,
          next_player_at_table: @state[:player_at_table].to_s,
          next_shots_left_in_turn: [@state[:shots_left_in_turn].to_i, 1].max
        }
      else
        next_shots = @state[:shots_left_in_turn].to_i - 1
        turn_ends = scoring[:foul] || next_shots <= 0
        {
          bonus_shot_awarded: false,
          turn_ends: turn_ends,
          next_player_at_table: turn_ends ? opponent_of(@state[:player_at_table].to_s) : @state[:player_at_table].to_s,
          next_shots_left_in_turn: turn_ends ? 2 : next_shots
        }
      end
    end

    # Phasenlogik für Serienspiel: Abbruch bei Fehler oder 0-Punkte-Stoß.
    def calculate_serienspiel_transitions(scoring)
      turn_ends = scoring[:foul] || scoring[:points_for_current_player].zero?
      {
        bonus_shot_awarded: false,
        turn_ends: turn_ends,
        next_player_at_table: turn_ends ? opponent_of(@state[:player_at_table].to_s) : @state[:player_at_table].to_s,
        next_shots_left_in_turn: nil
      }
    end

    # Bonusstoß-Qualifikation: 5 Kegel (ggf. mit Carom) im Direkten Zweikampf.
    def bonus_shot?(obs)
      obs[:fallen_pins].to_i == 5
    end

    # Gegenspieler bestimmen (playera ↔ playerb).
    def opponent_of(player)
      (player == "playera") ? "playerb" : "playera"
    end
  end
end
