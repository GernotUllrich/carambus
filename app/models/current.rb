# A word of caution: It's easy to overdo a global singleton like Current and tangle your model as a result.
# Current should only be used for a few, top-level globals, like account, user, and request details.
# The attributes stuck in Current should be used by more or less all actions on all requests.
# If you start sticking controller-specific attributes in there, you're going to create a mess.

class Current < ActiveSupport::CurrentAttributes
  attribute :user, :request_id, :user_agent, :ip_address
  # Globaler Ausschnitt (Scope-Band): { "region_id" => id, "season_id" => id, ... }.
  # Wird pro Request aus der Session gesetzt; SearchService wendet es als FK-Filter an.
  attribute :scope
  # Drill-down-Kontext (ephemerer Parent-FK, z.B. { "club_id" => id }): getrennt vom Scope-Band,
  # damit SearchService ihn DIREKT filtert (where(fk => id)) und NICHT die Scope-Facetten-Logik
  # (club_id-Join) durchläuft — nur so filtert der Drill auch Modelle wie SeasonParticipation/LeagueTeam.
  attribute :drill

  resets do
    Time.zone = nil
  end

  def user=(value)
    super
    Time.zone = Time.find_zone(value&.time_zone)
  end
end
