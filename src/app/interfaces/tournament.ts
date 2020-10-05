export interface Tournament {
  id: number;
  title: string;
  organizing_club_shortname: string;
  datum: string;
  location: string;
  discipline: string;
  playerlist: object;
  gamelist: object;
}
