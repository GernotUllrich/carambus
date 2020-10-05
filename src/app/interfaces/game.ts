export interface Game {
  id: number;
  name: string;
  status: string;
  game_start: string; // TODO should be datetime
  tournament_id: number;
  current_player_id: number;
  current_inning: number;
  timer_state: string;
  timer_end_time: string; // TODO should be datetime
  pause_state: string;
  pause_end_time: string; // TODO should be datetime
  player_1_id: number;
  player_2_id: number;
  player_3_id: number;
  player_4_id: number;
  player_1_score_list: object;
  player_2_score_list: object;
  player_3_score_list: object;
  player_4_score_list: object;
  player_1_innings_goal: number;
  player_2_innings_goal: number;
  player_3_innings_goal: number;
  player_4_innings_goal: number;
}
