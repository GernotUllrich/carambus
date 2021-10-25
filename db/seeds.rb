user_id_map = {}
created_at = Time.at(1617048163.6406898)
updated_at = Time.at(1617048163.6406898)
accepted_terms_at = Time.at(1617048163.6405199)
accepted_privacy_at = Time.at(1617048163.640557)
obj_was = User.where("id"=>50000002, "email"=>"iptvit412@gmail.com", "first_name"=>"Gernot", "last_name"=>"Ullrich", "time_zone"=>"Berlin", "admin"=>nil, "invitation_token"=>nil, "invitation_sent_at"=>nil, "invitation_limit"=>nil, "invited_by_type"=>nil, "invited_by_id"=>nil, "invitations_count"=>0, "preferred_language"=>nil, "username"=>nil, "firstname"=>nil, "lastname"=>nil, "player_id"=>nil, created_at: created_at, updated_at: updated_at, accepted_terms_at: accepted_terms_at, accepted_privacy_at: accepted_privacy_at).first
if obj_was.blank?
  obj_was = User.where("email"=>"iptvit412@gmail.com", "first_name"=>"Gernot", "last_name"=>"Ullrich", "time_zone"=>"Berlin", "admin"=>nil, "invitation_token"=>nil, "invitation_sent_at"=>nil, "invitation_limit"=>nil, "invited_by_type"=>nil, "invited_by_id"=>nil, "invitations_count"=>0, "preferred_language"=>nil, "username"=>nil, "firstname"=>nil, "lastname"=>nil, "player_id"=>nil).first
  if obj_was.blank?
    obj = User.new("email"=>"iptvit412@gmail.com", "first_name"=>"Gernot", "last_name"=>"Ullrich", "time_zone"=>"Berlin", "admin"=>nil, "invitation_token"=>nil, "invitation_sent_at"=>nil, "invitation_limit"=>nil, "invited_by_type"=>nil, "invited_by_id"=>nil, "invitations_count"=>0, "preferred_language"=>nil, "username"=>nil, "firstname"=>nil, "lastname"=>nil, "player_id"=>nil)
    obj.password = "******"
    obj.terms_of_service = true
    created_at = Time.at(1617048163.6406898)
    updated_at = Time.at(1617048163.6406898)
    accepted_terms_at = Time.at(1617048163.6405199)
    accepted_privacy_at = Time.at(1617048163.640557)
    begin
      obj.save!
      obj.update_column(:encrypted_password, "$2a$11$oVPU6fRN3u/G4DO020nxmu5QC/IyhB5dXUurxOmYIbuReX0BtFs3u")
      id = obj.id
      user_id_map[50000002] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"accepted_terms_at", accepted_terms_at)
      obj.update_column(:"accepted_privacy_at", accepted_privacy_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    user_id_map[50000002] = id
  end
end
account_id_map = {}
#+++Account+++
#---User---
h1 = JSON.pretty_generate(user_id_map)
created_at = Time.at(1617048163.714158)
updated_at = Time.at(1617048163.714158)
obj_was = Account.where("id"=>50000002, "name"=>"Gernot Ullrich", "owner_id"=>50000002, "personal"=>true, "processor"=>nil, "processor_id"=>nil, "card_type"=>nil, "card_last4"=>nil, "card_exp_month"=>nil, "card_exp_year"=>nil, "extra_billing_info"=>nil, "domain"=>nil, "subdomain"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Account.where("name"=>"Gernot Ullrich", "owner_id"=>50000002, "personal"=>true, "processor"=>nil, "processor_id"=>nil, "card_type"=>nil, "card_last4"=>nil, "card_exp_month"=>nil, "card_exp_year"=>nil, "extra_billing_info"=>nil, "domain"=>nil, "subdomain"=>nil).first
  if obj_was.blank?
    obj = Account.new("name"=>"Gernot Ullrich", "owner_id"=>50000002, "personal"=>true, "processor"=>nil, "processor_id"=>nil, "card_type"=>nil, "card_last4"=>nil, "card_exp_month"=>nil, "card_exp_year"=>nil, "extra_billing_info"=>nil, "domain"=>nil, "subdomain"=>nil)
    obj.owner_id = user_id_map[50000002] if user_id_map[50000002].present?
    obj.plan = nil
    obj.quantity = nil
    obj.card_token = nil
    created_at = Time.at(1617048163.714158)
    updated_at = Time.at(1617048163.714158)
    begin
      obj.save!
      id = obj.id
      account_id_map[50000002] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    account_id_map[50000002] = id
  end
end
account_user_id_map = {}
#+++AccountUser+++
#---Account---
h1 = JSON.pretty_generate(account_id_map)
#---User---
h2 = JSON.pretty_generate(user_id_map)
created_at = Time.at(1617048163.720553)
updated_at = Time.at(1617048163.720553)
obj_was = AccountUser.where("id"=>50000002, "account_id"=>50000002, "user_id"=>50000002, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = AccountUser.where("account_id"=>50000002, "user_id"=>50000002).first
  if obj_was.blank?
    obj = AccountUser.new("account_id"=>50000002, "user_id"=>50000002)
    obj.account_id = account_id_map[50000002] if account_id_map[50000002].present?
    obj.user_id = user_id_map[50000002] if user_id_map[50000002].present?
    roles = {"admin"=>true}
    obj.roles = roles
    created_at = Time.at(1617048163.720553)
    updated_at = Time.at(1617048163.720553)
    begin
      obj.save!
      id = obj.id
      account_user_id_map[50000002] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    account_user_id_map[50000002] = id
  end
end
player_id_map = {}
created_at = Time.at(1628695675.874288)
updated_at = Time.at(1628695675.874288)
obj_was = Player.where("id"=>50000001, "ba_id"=>nil, "club_id"=>357, "lastname"=>"von Husen", "firstname"=>"Jonny", "title"=>"", "guest"=>true, "nickname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Player.where("ba_id"=>nil, "club_id"=>357, "lastname"=>"von Husen", "firstname"=>"Jonny", "title"=>"", "guest"=>true, "nickname"=>nil).first
  if obj_was.blank?
    obj = Player.new("ba_id"=>nil, "club_id"=>357, "lastname"=>"von Husen", "firstname"=>"Jonny", "title"=>"", "guest"=>true, "nickname"=>nil)
    created_at = Time.at(1628695675.874288)
    updated_at = Time.at(1628695675.874288)
    begin
      obj.save!
      id = obj.id
      player_id_map[50000001] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    player_id_map[50000001] = id
  end
end
created_at = Time.at(1631205502.49337)
updated_at = Time.at(1631205612.517131)
obj_was = Player.where("id"=>50000002, "ba_id"=>nil, "club_id"=>357, "lastname"=>"Buschmann", "firstname"=>"Jochen", "title"=>"", "guest"=>true, "nickname"=>"", created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Player.where("ba_id"=>nil, "club_id"=>357, "lastname"=>"Buschmann", "firstname"=>"Jochen", "title"=>"", "guest"=>true, "nickname"=>"").first
  if obj_was.blank?
    obj = Player.new("ba_id"=>nil, "club_id"=>357, "lastname"=>"Buschmann", "firstname"=>"Jochen", "title"=>"", "guest"=>true, "nickname"=>"")
    created_at = Time.at(1631205502.49337)
    updated_at = Time.at(1631205612.517131)
    begin
      obj.save!
      id = obj.id
      player_id_map[50000002] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    player_id_map[50000002] = id
  end
end
tournament_id_map = {}
date = Time.at(0.0)
created_at = Time.at(1615410950.807683)
updated_at = Time.at(1618078608.219834)
obj_was = Tournament.where("id"=>50000001, "title"=>"Otto Pokal", "discipline_id"=>34, "modus"=>nil, "age_restriction"=>nil, "accredation_end"=>nil, "location"=>nil, "ba_id"=>nil, "season_id"=>12, "region_id"=>nil, "end_date"=>nil, "plan_or_show"=>nil, "single_or_league"=>nil, "shortname"=>nil, "ba_state"=>nil, "state"=>"tournament_started", "last_ba_sync_date"=>nil, "player_class"=>"", "tournament_plan_id"=>50000027, "innings_goal"=>nil, "balls_goal"=>nil, "handicap_tournier"=>true, "timeout"=>45, "time_out_warm_up_first_min"=>5, "time_out_warm_up_follow_up_min"=>3, "organizer_id"=>357, "organizer_type"=>"Club", "location_id"=>1, "manual_assignment"=>true, "timeouts"=>0, "admin_controlled"=>false, date: date, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Tournament.where("title"=>"Otto Pokal", "discipline_id"=>34, "modus"=>nil, "age_restriction"=>nil, "accredation_end"=>nil, "location"=>nil, "ba_id"=>nil, "season_id"=>12, "region_id"=>nil, "end_date"=>nil, "plan_or_show"=>nil, "single_or_league"=>nil, "shortname"=>nil, "ba_state"=>nil, "state"=>"tournament_started", "last_ba_sync_date"=>nil, "player_class"=>"", "tournament_plan_id"=>50000027, "innings_goal"=>nil, "balls_goal"=>nil, "handicap_tournier"=>true, "timeout"=>45, "time_out_warm_up_first_min"=>5, "time_out_warm_up_follow_up_min"=>3, "organizer_id"=>357, "organizer_type"=>"Club", "location_id"=>1, "manual_assignment"=>true, "timeouts"=>0, "admin_controlled"=>false).first
  if obj_was.blank?
    obj = Tournament.new("title"=>"Otto Pokal", "discipline_id"=>34, "modus"=>nil, "age_restriction"=>nil, "accredation_end"=>nil, "location"=>nil, "ba_id"=>nil, "season_id"=>12, "region_id"=>nil, "end_date"=>nil, "plan_or_show"=>nil, "single_or_league"=>nil, "shortname"=>nil, "ba_state"=>nil, "state"=>"tournament_started", "last_ba_sync_date"=>nil, "player_class"=>"", "tournament_plan_id"=>50000027, "innings_goal"=>nil, "balls_goal"=>nil, "handicap_tournier"=>true, "timeout"=>45, "time_out_warm_up_first_min"=>5, "time_out_warm_up_follow_up_min"=>3, "organizer_id"=>357, "organizer_type"=>"Club", "location_id"=>1, "manual_assignment"=>true, "timeouts"=>0, "admin_controlled"=>false)
    data = {:table_ids=>["1", "2", "3", "4"]}
    obj.data = data
    date = Time.at(0.0)
    created_at = Time.at(1615410950.807683)
    updated_at = Time.at(1618078608.219834)
    begin
      obj.save!
      id = obj.id
      tournament_id_map[50000001] = id
      obj.update_column(:"date", date)
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    tournament_id_map[50000001] = id
  end
end
date = Time.at(0.0)
created_at = Time.at(1628695727.824866)
updated_at = Time.at(1629042224.3320441)
obj_was = Tournament.where("id"=>50000003, "title"=>"Ottopokal 2021", "discipline_id"=>34, "modus"=>nil, "age_restriction"=>nil, "accredation_end"=>nil, "location"=>nil, "ba_id"=>nil, "season_id"=>13, "region_id"=>nil, "end_date"=>nil, "plan_or_show"=>nil, "single_or_league"=>nil, "shortname"=>nil, "ba_state"=>nil, "state"=>"tournament_started", "last_ba_sync_date"=>nil, "player_class"=>"", "tournament_plan_id"=>50000027, "innings_goal"=>nil, "balls_goal"=>nil, "handicap_tournier"=>true, "timeout"=>0, "time_out_warm_up_first_min"=>5, "time_out_warm_up_follow_up_min"=>3, "organizer_id"=>357, "organizer_type"=>"Club", "location_id"=>1, "manual_assignment"=>true, "timeouts"=>0, "admin_controlled"=>false, date: date, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Tournament.where("title"=>"Ottopokal 2021", "discipline_id"=>34, "modus"=>nil, "age_restriction"=>nil, "accredation_end"=>nil, "location"=>nil, "ba_id"=>nil, "season_id"=>13, "region_id"=>nil, "end_date"=>nil, "plan_or_show"=>nil, "single_or_league"=>nil, "shortname"=>nil, "ba_state"=>nil, "state"=>"tournament_started", "last_ba_sync_date"=>nil, "player_class"=>"", "tournament_plan_id"=>50000027, "innings_goal"=>nil, "balls_goal"=>nil, "handicap_tournier"=>true, "timeout"=>0, "time_out_warm_up_first_min"=>5, "time_out_warm_up_follow_up_min"=>3, "organizer_id"=>357, "organizer_type"=>"Club", "location_id"=>1, "manual_assignment"=>true, "timeouts"=>0, "admin_controlled"=>false).first
  if obj_was.blank?
    obj = Tournament.new("title"=>"Ottopokal 2021", "discipline_id"=>34, "modus"=>nil, "age_restriction"=>nil, "accredation_end"=>nil, "location"=>nil, "ba_id"=>nil, "season_id"=>13, "region_id"=>nil, "end_date"=>nil, "plan_or_show"=>nil, "single_or_league"=>nil, "shortname"=>nil, "ba_state"=>nil, "state"=>"tournament_started", "last_ba_sync_date"=>nil, "player_class"=>"", "tournament_plan_id"=>50000027, "innings_goal"=>nil, "balls_goal"=>nil, "handicap_tournier"=>true, "timeout"=>0, "time_out_warm_up_first_min"=>5, "time_out_warm_up_follow_up_min"=>3, "organizer_id"=>357, "organizer_type"=>"Club", "location_id"=>1, "manual_assignment"=>true, "timeouts"=>0, "admin_controlled"=>false)
    data = {:table_ids=>["1", "2", "3", "4"], :balls_goal=>0, :innings_goal=>0, :timeout=>0, :timeouts=>0, :time_out_warm_up_first_min=>5, :time_out_warm_up_follow_up_min=>3}
    obj.data = data
    date = Time.at(0.0)
    created_at = Time.at(1628695727.824866)
    updated_at = Time.at(1629042224.3320441)
    begin
      obj.save!
      id = obj.id
      tournament_id_map[50000003] = id
      obj.update_column(:"date", date)
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    tournament_id_map[50000003] = id
  end
end
seeding_id_map = {}
#+++Seeding+++
#---Tournament---
h1 = JSON.pretty_generate(tournament_id_map)
#---Player---
h2 = JSON.pretty_generate(player_id_map)
created_at = Time.at(1615887899.428042)
updated_at = Time.at(1615887905.131008)
obj_was = Seeding.where("id"=>50000263, "player_id"=>265, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>205, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>265, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>205, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>265, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>205, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000001] if tournament_id_map[50000001].present?
    obj.player_id = player_id_map[265] if player_id_map[265].present?
    created_at = Time.at(1615887899.428042)
    updated_at = Time.at(1615887905.131008)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000263] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000263] = id
  end
end
created_at = Time.at(1615887913.312726)
updated_at = Time.at(1615887918.9975412)
obj_was = Seeding.where("id"=>50000264, "player_id"=>267, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>2, "state"=>"registered", "balls_goal"=>150, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>267, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>2, "state"=>"registered", "balls_goal"=>150, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>267, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>2, "state"=>"registered", "balls_goal"=>150, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000001] if tournament_id_map[50000001].present?
    obj.player_id = player_id_map[267] if player_id_map[267].present?
    created_at = Time.at(1615887913.312726)
    updated_at = Time.at(1615887918.9975412)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000264] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000264] = id
  end
end
created_at = Time.at(1615887929.5100071)
updated_at = Time.at(1615887933.88657)
obj_was = Seeding.where("id"=>50000265, "player_id"=>262, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>3, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>262, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>3, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>262, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>3, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000001] if tournament_id_map[50000001].present?
    obj.player_id = player_id_map[262] if player_id_map[262].present?
    created_at = Time.at(1615887929.5100071)
    updated_at = Time.at(1615887933.88657)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000265] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000265] = id
  end
end
created_at = Time.at(1615887940.941055)
updated_at = Time.at(1615887946.1174688)
obj_was = Seeding.where("id"=>50000266, "player_id"=>257, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>4, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>257, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>4, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>257, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>4, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000001] if tournament_id_map[50000001].present?
    obj.player_id = player_id_map[257] if player_id_map[257].present?
    created_at = Time.at(1615887940.941055)
    updated_at = Time.at(1615887946.1174688)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000266] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000266] = id
  end
end
created_at = Time.at(1615887952.6338508)
updated_at = Time.at(1615887956.5982442)
obj_was = Seeding.where("id"=>50000267, "player_id"=>268, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>5, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>268, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>5, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>268, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>5, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000001] if tournament_id_map[50000001].present?
    obj.player_id = player_id_map[268] if player_id_map[268].present?
    created_at = Time.at(1615887952.6338508)
    updated_at = Time.at(1615887956.5982442)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000267] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000267] = id
  end
end
created_at = Time.at(1615887963.701869)
updated_at = Time.at(1615887966.809324)
obj_was = Seeding.where("id"=>50000268, "player_id"=>261, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>6, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>261, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>6, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>261, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>6, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000001] if tournament_id_map[50000001].present?
    obj.player_id = player_id_map[261] if player_id_map[261].present?
    created_at = Time.at(1615887963.701869)
    updated_at = Time.at(1615887966.809324)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000268] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000268] = id
  end
end
created_at = Time.at(1615887972.2010639)
updated_at = Time.at(1615887975.715296)
obj_was = Seeding.where("id"=>50000269, "player_id"=>255, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>7, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>255, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>7, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>255, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>7, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000001] if tournament_id_map[50000001].present?
    obj.player_id = player_id_map[255] if player_id_map[255].present?
    created_at = Time.at(1615887972.2010639)
    updated_at = Time.at(1615887975.715296)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000269] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000269] = id
  end
end
created_at = Time.at(1615887980.3122308)
updated_at = Time.at(1618078538.0609121)
obj_was = Seeding.where("id"=>50000270, "player_id"=>266, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>9, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>266, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>9, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>266, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>9, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000001] if tournament_id_map[50000001].present?
    obj.player_id = player_id_map[266] if player_id_map[266].present?
    created_at = Time.at(1615887980.3122308)
    updated_at = Time.at(1618078538.0609121)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000270] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000270] = id
  end
end
created_at = Time.at(1615887991.606362)
updated_at = Time.at(1618078538.0799282)
obj_was = Seeding.where("id"=>50000271, "player_id"=>252, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>10, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>252, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>10, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>252, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>10, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000001] if tournament_id_map[50000001].present?
    obj.player_id = player_id_map[252] if player_id_map[252].present?
    created_at = Time.at(1615887991.606362)
    updated_at = Time.at(1618078538.0799282)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000271] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000271] = id
  end
end
created_at = Time.at(1615888010.235811)
updated_at = Time.at(1618078538.101274)
obj_was = Seeding.where("id"=>50000272, "player_id"=>254, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>16, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>254, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>16, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>254, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>16, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000001] if tournament_id_map[50000001].present?
    obj.player_id = player_id_map[254] if player_id_map[254].present?
    created_at = Time.at(1615888010.235811)
    updated_at = Time.at(1618078538.101274)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000272] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000272] = id
  end
end
created_at = Time.at(1615888047.915242)
updated_at = Time.at(1618078538.119643)
obj_was = Seeding.where("id"=>50000273, "player_id"=>247, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>11, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>247, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>11, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>247, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>11, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000001] if tournament_id_map[50000001].present?
    obj.player_id = player_id_map[247] if player_id_map[247].present?
    created_at = Time.at(1615888047.915242)
    updated_at = Time.at(1618078538.119643)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000273] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000273] = id
  end
end
created_at = Time.at(1615888056.5216908)
updated_at = Time.at(1618078538.119643)
obj_was = Seeding.where("id"=>50000274, "player_id"=>249, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>12, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>249, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>12, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>249, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>12, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000001] if tournament_id_map[50000001].present?
    obj.player_id = player_id_map[249] if player_id_map[249].present?
    created_at = Time.at(1615888056.5216908)
    updated_at = Time.at(1618078538.119643)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000274] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000274] = id
  end
end
created_at = Time.at(1615888065.016402)
updated_at = Time.at(1618078538.119643)
obj_was = Seeding.where("id"=>50000275, "player_id"=>263, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>13, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>263, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>13, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>263, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>13, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000001] if tournament_id_map[50000001].present?
    obj.player_id = player_id_map[263] if player_id_map[263].present?
    created_at = Time.at(1615888065.016402)
    updated_at = Time.at(1618078538.119643)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000275] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000275] = id
  end
end
created_at = Time.at(1615888083.452251)
updated_at = Time.at(1618078538.119643)
obj_was = Seeding.where("id"=>50000276, "player_id"=>251, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>14, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>251, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>14, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>251, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>14, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000001] if tournament_id_map[50000001].present?
    obj.player_id = player_id_map[251] if player_id_map[251].present?
    created_at = Time.at(1615888083.452251)
    updated_at = Time.at(1618078538.119643)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000276] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000276] = id
  end
end
created_at = Time.at(1615888092.24129)
updated_at = Time.at(1618078538.119643)
obj_was = Seeding.where("id"=>50000277, "player_id"=>256, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>15, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>256, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>15, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>256, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>15, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000001] if tournament_id_map[50000001].present?
    obj.player_id = player_id_map[256] if player_id_map[256].present?
    created_at = Time.at(1615888092.24129)
    updated_at = Time.at(1618078538.119643)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000277] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000277] = id
  end
end
created_at = Time.at(1618078496.811869)
updated_at = Time.at(1618078538.0007749)
obj_was = Seeding.where("id"=>50000498, "player_id"=>250, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>8, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>250, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>8, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>250, "tournament_id"=>50000001, "ba_state"=>nil, "position"=>8, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000001] if tournament_id_map[50000001].present?
    obj.player_id = player_id_map[250] if player_id_map[250].present?
    created_at = Time.at(1618078496.811869)
    updated_at = Time.at(1618078538.0007749)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000498] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000498] = id
  end
end
created_at = Time.at(1628009084.565724)
updated_at = Time.at(1628009100.782967)
obj_was = Seeding.where("id"=>50000583, "player_id"=>247, "tournament_id"=>50000002, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>247, "tournament_id"=>50000002, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>247, "tournament_id"=>50000002, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000002] if tournament_id_map[50000002].present?
    obj.player_id = player_id_map[247] if player_id_map[247].present?
    created_at = Time.at(1628009084.565724)
    updated_at = Time.at(1628009100.782967)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000583] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000583] = id
  end
end
created_at = Time.at(1628009087.606517)
updated_at = Time.at(1628009114.371338)
obj_was = Seeding.where("id"=>50000584, "player_id"=>252, "tournament_id"=>50000002, "ba_state"=>nil, "position"=>2, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>252, "tournament_id"=>50000002, "ba_state"=>nil, "position"=>2, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>252, "tournament_id"=>50000002, "ba_state"=>nil, "position"=>2, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000002] if tournament_id_map[50000002].present?
    obj.player_id = player_id_map[252] if player_id_map[252].present?
    created_at = Time.at(1628009087.606517)
    updated_at = Time.at(1628009114.371338)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000584] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000584] = id
  end
end
created_at = Time.at(1628296678.0541692)
updated_at = Time.at(1628296678.744543)
obj_was = Seeding.where("id"=>50000649, "player_id"=>274, "tournament_id"=>61, "ba_state"=>nil, "position"=>9, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>274, "tournament_id"=>61, "ba_state"=>nil, "position"=>9, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>274, "tournament_id"=>61, "ba_state"=>nil, "position"=>9, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[61] if tournament_id_map[61].present?
    obj.player_id = player_id_map[274] if player_id_map[274].present?
    created_at = Time.at(1628296678.0541692)
    updated_at = Time.at(1628296678.744543)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000649] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000649] = id
  end
end
created_at = Time.at(1628296678.109308)
updated_at = Time.at(1628296678.781636)
obj_was = Seeding.where("id"=>50000650, "player_id"=>23386, "tournament_id"=>61, "ba_state"=>nil, "position"=>10, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>23386, "tournament_id"=>61, "ba_state"=>nil, "position"=>10, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>23386, "tournament_id"=>61, "ba_state"=>nil, "position"=>10, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[61] if tournament_id_map[61].present?
    obj.player_id = player_id_map[23386] if player_id_map[23386].present?
    created_at = Time.at(1628296678.109308)
    updated_at = Time.at(1628296678.781636)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000650] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000650] = id
  end
end
created_at = Time.at(1628296678.128656)
updated_at = Time.at(1628296678.79935)
obj_was = Seeding.where("id"=>50000651, "player_id"=>265, "tournament_id"=>61, "ba_state"=>nil, "position"=>11, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>265, "tournament_id"=>61, "ba_state"=>nil, "position"=>11, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>265, "tournament_id"=>61, "ba_state"=>nil, "position"=>11, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[61] if tournament_id_map[61].present?
    obj.player_id = player_id_map[265] if player_id_map[265].present?
    created_at = Time.at(1628296678.128656)
    updated_at = Time.at(1628296678.79935)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000651] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000651] = id
  end
end
created_at = Time.at(1628296678.1430569)
updated_at = Time.at(1628296678.817238)
obj_was = Seeding.where("id"=>50000652, "player_id"=>266, "tournament_id"=>61, "ba_state"=>nil, "position"=>12, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>266, "tournament_id"=>61, "ba_state"=>nil, "position"=>12, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>266, "tournament_id"=>61, "ba_state"=>nil, "position"=>12, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[61] if tournament_id_map[61].present?
    obj.player_id = player_id_map[266] if player_id_map[266].present?
    created_at = Time.at(1628296678.1430569)
    updated_at = Time.at(1628296678.817238)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000652] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000652] = id
  end
end
created_at = Time.at(1628296678.1585128)
updated_at = Time.at(1628296678.835653)
obj_was = Seeding.where("id"=>50000653, "player_id"=>268, "tournament_id"=>61, "ba_state"=>nil, "position"=>13, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>268, "tournament_id"=>61, "ba_state"=>nil, "position"=>13, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>268, "tournament_id"=>61, "ba_state"=>nil, "position"=>13, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[61] if tournament_id_map[61].present?
    obj.player_id = player_id_map[268] if player_id_map[268].present?
    created_at = Time.at(1628296678.1585128)
    updated_at = Time.at(1628296678.835653)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000653] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000653] = id
  end
end
created_at = Time.at(1628296678.17579)
updated_at = Time.at(1628296678.8526871)
obj_was = Seeding.where("id"=>50000654, "player_id"=>23010, "tournament_id"=>61, "ba_state"=>nil, "position"=>14, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>23010, "tournament_id"=>61, "ba_state"=>nil, "position"=>14, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>23010, "tournament_id"=>61, "ba_state"=>nil, "position"=>14, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[61] if tournament_id_map[61].present?
    obj.player_id = player_id_map[23010] if player_id_map[23010].present?
    created_at = Time.at(1628296678.17579)
    updated_at = Time.at(1628296678.8526871)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000654] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000654] = id
  end
end
created_at = Time.at(1628296678.2037199)
updated_at = Time.at(1628296678.869743)
obj_was = Seeding.where("id"=>50000655, "player_id"=>15626, "tournament_id"=>61, "ba_state"=>nil, "position"=>15, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>15626, "tournament_id"=>61, "ba_state"=>nil, "position"=>15, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>15626, "tournament_id"=>61, "ba_state"=>nil, "position"=>15, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[61] if tournament_id_map[61].present?
    obj.player_id = player_id_map[15626] if player_id_map[15626].present?
    created_at = Time.at(1628296678.2037199)
    updated_at = Time.at(1628296678.869743)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000655] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000655] = id
  end
end
created_at = Time.at(1628296678.218585)
updated_at = Time.at(1628296678.340252)
obj_was = Seeding.where("id"=>50000656, "player_id"=>259, "tournament_id"=>61, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>259, "tournament_id"=>61, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>259, "tournament_id"=>61, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[61] if tournament_id_map[61].present?
    obj.player_id = player_id_map[259] if player_id_map[259].present?
    created_at = Time.at(1628296678.218585)
    updated_at = Time.at(1628296678.340252)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000656] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000656] = id
  end
end
created_at = Time.at(1628695779.947242)
updated_at = Time.at(1629039501.0762482)
obj_was = Seeding.where("id"=>50000657, "player_id"=>261, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>261, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>261, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    obj.player_id = player_id_map[261] if player_id_map[261].present?
    created_at = Time.at(1628695779.947242)
    updated_at = Time.at(1629039501.0762482)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000657] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000657] = id
  end
end
created_at = Time.at(1628695785.045123)
updated_at = Time.at(1629227331.9061089)
obj_was = Seeding.where("id"=>50000658, "player_id"=>257, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>4, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>257, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>4, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>257, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>4, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    obj.player_id = player_id_map[257] if player_id_map[257].present?
    created_at = Time.at(1628695785.045123)
    updated_at = Time.at(1629227331.9061089)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000658] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000658] = id
  end
end
created_at = Time.at(1628695788.033791)
updated_at = Time.at(1629227328.2737322)
obj_was = Seeding.where("id"=>50000659, "player_id"=>255, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>5, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>255, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>5, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>255, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>5, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    obj.player_id = player_id_map[255] if player_id_map[255].present?
    created_at = Time.at(1628695788.033791)
    updated_at = Time.at(1629227328.2737322)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000659] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000659] = id
  end
end
created_at = Time.at(1628695792.655148)
updated_at = Time.at(1629227311.7818098)
obj_was = Seeding.where("id"=>50000660, "player_id"=>266, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>8, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>266, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>8, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>266, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>8, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    obj.player_id = player_id_map[266] if player_id_map[266].present?
    created_at = Time.at(1628695792.655148)
    updated_at = Time.at(1629227311.7818098)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000660] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000660] = id
  end
end
created_at = Time.at(1628695795.943357)
updated_at = Time.at(1629227306.445858)
obj_was = Seeding.where("id"=>50000661, "player_id"=>254, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>9, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>254, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>9, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>254, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>9, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    obj.player_id = player_id_map[254] if player_id_map[254].present?
    created_at = Time.at(1628695795.943357)
    updated_at = Time.at(1629227306.445858)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000661] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000661] = id
  end
end
created_at = Time.at(1628695800.2189791)
updated_at = Time.at(1629227281.414886)
obj_was = Seeding.where("id"=>50000662, "player_id"=>247, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>12, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>247, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>12, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>247, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>12, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    obj.player_id = player_id_map[247] if player_id_map[247].present?
    created_at = Time.at(1628695800.2189791)
    updated_at = Time.at(1629227281.414886)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000662] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000662] = id
  end
end
created_at = Time.at(1628695809.768521)
updated_at = Time.at(1629227271.397074)
obj_was = Seeding.where("id"=>50000663, "player_id"=>263, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>13, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>263, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>13, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>263, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>13, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    obj.player_id = player_id_map[263] if player_id_map[263].present?
    created_at = Time.at(1628695809.768521)
    updated_at = Time.at(1629227271.397074)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000663] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000663] = id
  end
end
created_at = Time.at(1628695821.826514)
updated_at = Time.at(1629227336.3525481)
obj_was = Seeding.where("id"=>50000665, "player_id"=>267, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>3, "state"=>"registered", "balls_goal"=>150, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>267, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>3, "state"=>"registered", "balls_goal"=>150, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>267, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>3, "state"=>"registered", "balls_goal"=>150, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    obj.player_id = player_id_map[267] if player_id_map[267].present?
    created_at = Time.at(1628695821.826514)
    updated_at = Time.at(1629227336.3525481)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000665] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000665] = id
  end
end
created_at = Time.at(1628695827.82931)
updated_at = Time.at(1629227323.3671)
obj_was = Seeding.where("id"=>50000666, "player_id"=>262, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>6, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>262, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>6, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>262, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>6, "state"=>"registered", "balls_goal"=>60, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    obj.player_id = player_id_map[262] if player_id_map[262].present?
    created_at = Time.at(1628695827.82931)
    updated_at = Time.at(1629227323.3671)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000666] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000666] = id
  end
end
created_at = Time.at(1628695846.731582)
updated_at = Time.at(1629227317.262626)
obj_was = Seeding.where("id"=>50000667, "player_id"=>252, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>7, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>252, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>7, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>252, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>7, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    obj.player_id = player_id_map[252] if player_id_map[252].present?
    created_at = Time.at(1628695846.731582)
    updated_at = Time.at(1629227317.262626)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000667] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000667] = id
  end
end
created_at = Time.at(1628695850.642999)
updated_at = Time.at(1629227302.1034691)
obj_was = Seeding.where("id"=>50000668, "player_id"=>50000001, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>10, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>50000001, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>10, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>50000001, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>10, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    obj.player_id = player_id_map[50000001] if player_id_map[50000001].present?
    created_at = Time.at(1628695850.642999)
    updated_at = Time.at(1629227302.1034691)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000668] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000668] = id
  end
end
created_at = Time.at(1628695857.1890829)
updated_at = Time.at(1629227296.573934)
obj_was = Seeding.where("id"=>50000669, "player_id"=>256, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>11, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>256, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>11, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>256, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>11, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    obj.player_id = player_id_map[256] if player_id_map[256].present?
    created_at = Time.at(1628695857.1890829)
    updated_at = Time.at(1629227296.573934)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000669] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000669] = id
  end
end
created_at = Time.at(1628695868.88808)
updated_at = Time.at(1629227385.211762)
obj_was = Seeding.where("id"=>50000671, "player_id"=>260, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>15, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>260, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>15, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>260, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>15, "state"=>"registered", "balls_goal"=>32, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    obj.player_id = player_id_map[260] if player_id_map[260].present?
    created_at = Time.at(1628695868.88808)
    updated_at = Time.at(1629227385.211762)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000671] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000671] = id
  end
end
created_at = Time.at(1628695898.9316218)
updated_at = Time.at(1629227374.656637)
obj_was = Seeding.where("id"=>50000672, "player_id"=>249, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>16, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>249, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>16, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>249, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>16, "state"=>"registered", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    obj.player_id = player_id_map[249] if player_id_map[249].present?
    created_at = Time.at(1628695898.9316218)
    updated_at = Time.at(1629227374.656637)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000672] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000672] = id
  end
end
created_at = Time.at(1629227119.701932)
updated_at = Time.at(1629230050.8284512)
obj_was = Seeding.where("id"=>50000673, "player_id"=>251, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>14, "state"=>"no_show", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>251, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>14, "state"=>"no_show", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>251, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>14, "state"=>"no_show", "balls_goal"=>16, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    obj.player_id = player_id_map[251] if player_id_map[251].present?
    created_at = Time.at(1629227119.701932)
    updated_at = Time.at(1629230050.8284512)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000673] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000673] = id
  end
end
created_at = Time.at(1629227135.320532)
updated_at = Time.at(1629230033.832022)
obj_was = Seeding.where("id"=>50000674, "player_id"=>265, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>2, "state"=>"no_show", "balls_goal"=>205, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>265, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>2, "state"=>"no_show", "balls_goal"=>205, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>265, "tournament_id"=>50000003, "ba_state"=>nil, "position"=>2, "state"=>"no_show", "balls_goal"=>205, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    obj.player_id = player_id_map[265] if player_id_map[265].present?
    created_at = Time.at(1629227135.320532)
    updated_at = Time.at(1629230033.832022)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000674] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000674] = id
  end
end
created_at = Time.at(1630954923.040749)
updated_at = Time.at(1630954923.529155)
obj_was = Seeding.where("id"=>50000681, "player_id"=>271, "tournament_id"=>11910, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>271, "tournament_id"=>11910, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>271, "tournament_id"=>11910, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[11910] if tournament_id_map[11910].present?
    obj.player_id = player_id_map[271] if player_id_map[271].present?
    created_at = Time.at(1630954923.040749)
    updated_at = Time.at(1630954923.529155)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000681] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000681] = id
  end
end
created_at = Time.at(1630954923.104417)
updated_at = Time.at(1630954923.69049)
obj_was = Seeding.where("id"=>50000682, "player_id"=>275, "tournament_id"=>11910, "ba_state"=>nil, "position"=>2, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>275, "tournament_id"=>11910, "ba_state"=>nil, "position"=>2, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>275, "tournament_id"=>11910, "ba_state"=>nil, "position"=>2, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[11910] if tournament_id_map[11910].present?
    obj.player_id = player_id_map[275] if player_id_map[275].present?
    created_at = Time.at(1630954923.104417)
    updated_at = Time.at(1630954923.69049)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000682] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000682] = id
  end
end
created_at = Time.at(1630954923.146088)
updated_at = Time.at(1630954923.752429)
obj_was = Seeding.where("id"=>50000683, "player_id"=>296, "tournament_id"=>11910, "ba_state"=>nil, "position"=>3, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>296, "tournament_id"=>11910, "ba_state"=>nil, "position"=>3, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>296, "tournament_id"=>11910, "ba_state"=>nil, "position"=>3, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[11910] if tournament_id_map[11910].present?
    obj.player_id = player_id_map[296] if player_id_map[296].present?
    created_at = Time.at(1630954923.146088)
    updated_at = Time.at(1630954923.752429)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000683] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000683] = id
  end
end
created_at = Time.at(1630954923.176896)
updated_at = Time.at(1630954923.803318)
obj_was = Seeding.where("id"=>50000684, "player_id"=>277, "tournament_id"=>11910, "ba_state"=>nil, "position"=>4, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>277, "tournament_id"=>11910, "ba_state"=>nil, "position"=>4, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>277, "tournament_id"=>11910, "ba_state"=>nil, "position"=>4, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[11910] if tournament_id_map[11910].present?
    obj.player_id = player_id_map[277] if player_id_map[277].present?
    created_at = Time.at(1630954923.176896)
    updated_at = Time.at(1630954923.803318)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000684] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000684] = id
  end
end
created_at = Time.at(1630954923.222518)
updated_at = Time.at(1630954923.857422)
obj_was = Seeding.where("id"=>50000685, "player_id"=>278, "tournament_id"=>11910, "ba_state"=>nil, "position"=>5, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>278, "tournament_id"=>11910, "ba_state"=>nil, "position"=>5, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>278, "tournament_id"=>11910, "ba_state"=>nil, "position"=>5, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[11910] if tournament_id_map[11910].present?
    obj.player_id = player_id_map[278] if player_id_map[278].present?
    created_at = Time.at(1630954923.222518)
    updated_at = Time.at(1630954923.857422)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000685] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000685] = id
  end
end
created_at = Time.at(1630954923.2522721)
updated_at = Time.at(1630954923.910123)
obj_was = Seeding.where("id"=>50000686, "player_id"=>299, "tournament_id"=>11910, "ba_state"=>nil, "position"=>6, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>299, "tournament_id"=>11910, "ba_state"=>nil, "position"=>6, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>299, "tournament_id"=>11910, "ba_state"=>nil, "position"=>6, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[11910] if tournament_id_map[11910].present?
    obj.player_id = player_id_map[299] if player_id_map[299].present?
    created_at = Time.at(1630954923.2522721)
    updated_at = Time.at(1630954923.910123)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000686] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000686] = id
  end
end
created_at = Time.at(1630954923.28318)
updated_at = Time.at(1630954923.9756968)
obj_was = Seeding.where("id"=>50000687, "player_id"=>301, "tournament_id"=>11910, "ba_state"=>nil, "position"=>7, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>301, "tournament_id"=>11910, "ba_state"=>nil, "position"=>7, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>301, "tournament_id"=>11910, "ba_state"=>nil, "position"=>7, "state"=>"registered", "balls_goal"=>nil, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[11910] if tournament_id_map[11910].present?
    obj.player_id = player_id_map[301] if player_id_map[301].present?
    created_at = Time.at(1630954923.28318)
    updated_at = Time.at(1630954923.9756968)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000687] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000687] = id
  end
end
created_at = Time.at(1631293229.414612)
updated_at = Time.at(1631293587.862303)
obj_was = Seeding.where("id"=>50000688, "player_id"=>294, "tournament_id"=>11911, "ba_state"=>nil, "position"=>5, "state"=>"registered", "balls_goal"=>5, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>294, "tournament_id"=>11911, "ba_state"=>nil, "position"=>5, "state"=>"registered", "balls_goal"=>5, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>294, "tournament_id"=>11911, "ba_state"=>nil, "position"=>5, "state"=>"registered", "balls_goal"=>5, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    obj.player_id = player_id_map[294] if player_id_map[294].present?
    created_at = Time.at(1631293229.414612)
    updated_at = Time.at(1631293587.862303)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000688] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000688] = id
  end
end
created_at = Time.at(1631293229.467498)
updated_at = Time.at(1631293564.88673)
obj_was = Seeding.where("id"=>50000689, "player_id"=>297, "tournament_id"=>11911, "ba_state"=>nil, "position"=>3, "state"=>"registered", "balls_goal"=>3, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>297, "tournament_id"=>11911, "ba_state"=>nil, "position"=>3, "state"=>"registered", "balls_goal"=>3, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>297, "tournament_id"=>11911, "ba_state"=>nil, "position"=>3, "state"=>"registered", "balls_goal"=>3, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    obj.player_id = player_id_map[297] if player_id_map[297].present?
    created_at = Time.at(1631293229.467498)
    updated_at = Time.at(1631293564.88673)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000689] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000689] = id
  end
end
created_at = Time.at(1631293229.5144)
updated_at = Time.at(1631293587.774882)
obj_was = Seeding.where("id"=>50000690, "player_id"=>252, "tournament_id"=>11911, "ba_state"=>nil, "position"=>6, "state"=>"registered", "balls_goal"=>6, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>252, "tournament_id"=>11911, "ba_state"=>nil, "position"=>6, "state"=>"registered", "balls_goal"=>6, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>252, "tournament_id"=>11911, "ba_state"=>nil, "position"=>6, "state"=>"registered", "balls_goal"=>6, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    obj.player_id = player_id_map[252] if player_id_map[252].present?
    created_at = Time.at(1631293229.5144)
    updated_at = Time.at(1631293587.774882)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000690] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000690] = id
  end
end
created_at = Time.at(1631293229.560416)
updated_at = Time.at(1631293544.175179)
obj_was = Seeding.where("id"=>50000691, "player_id"=>255, "tournament_id"=>11911, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>1, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>255, "tournament_id"=>11911, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>1, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>255, "tournament_id"=>11911, "ba_state"=>nil, "position"=>1, "state"=>"registered", "balls_goal"=>1, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    obj.player_id = player_id_map[255] if player_id_map[255].present?
    created_at = Time.at(1631293229.560416)
    updated_at = Time.at(1631293544.175179)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000691] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000691] = id
  end
end
created_at = Time.at(1631293229.606761)
updated_at = Time.at(1631293564.976245)
obj_was = Seeding.where("id"=>50000692, "player_id"=>259, "tournament_id"=>11911, "ba_state"=>nil, "position"=>2, "state"=>"registered", "balls_goal"=>2, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>259, "tournament_id"=>11911, "ba_state"=>nil, "position"=>2, "state"=>"registered", "balls_goal"=>2, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>259, "tournament_id"=>11911, "ba_state"=>nil, "position"=>2, "state"=>"registered", "balls_goal"=>2, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    obj.player_id = player_id_map[259] if player_id_map[259].present?
    created_at = Time.at(1631293229.606761)
    updated_at = Time.at(1631293564.976245)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000692] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000692] = id
  end
end
created_at = Time.at(1631293229.654043)
updated_at = Time.at(1631293584.069487)
obj_was = Seeding.where("id"=>50000693, "player_id"=>266, "tournament_id"=>11911, "ba_state"=>nil, "position"=>4, "state"=>"registered", "balls_goal"=>4, "playing_discipline_id"=>nil, "rank"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Seeding.where("player_id"=>266, "tournament_id"=>11911, "ba_state"=>nil, "position"=>4, "state"=>"registered", "balls_goal"=>4, "playing_discipline_id"=>nil, "rank"=>nil).first
  if obj_was.blank?
    obj = Seeding.new("player_id"=>266, "tournament_id"=>11911, "ba_state"=>nil, "position"=>4, "state"=>"registered", "balls_goal"=>4, "playing_discipline_id"=>nil, "rank"=>nil)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    obj.player_id = player_id_map[266] if player_id_map[266].present?
    created_at = Time.at(1631293229.654043)
    updated_at = Time.at(1631293584.069487)
    begin
      obj.save!
      id = obj.id
      seeding_id_map[50000693] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    seeding_id_map[50000693] = id
  end
end
game_id_map = {}
#---Tournament---
h1 = JSON.pretty_generate(tournament_id_map)
created_at = Time.at(1629042224.529831)
updated_at = Time.at(1629118932.120203)
started_at = Time.at(1629118802.06834)
ended_at = Time.at(1629118924.508991)
obj_was = Game.where("id"=>50006123, "tournament_id"=>50000003, "seqno"=>3, "gname"=>"group1:1-2", "group_no"=>1, "table_no"=>4, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>3, "gname"=>"group1:1-2", "group_no"=>1, "table_no"=>4, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>3, "gname"=>"group1:1-2", "group_no"=>1, "table_no"=>4, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>3, "Spieler1"=>366548, "Spieler2"=>121315, "Ergebnis1"=>41, "Ergebnis2"=>60, "Aufnahmen1"=>11, "Aufnahmen2"=>11, "Höchstserie1"=>12, "Höchstserie2"=>13, "Tischnummer"=>4}}
    obj.data = data
    created_at = Time.at(1629042224.529831)
    updated_at = Time.at(1629118932.120203)
    started_at = Time.at(1629118802.06834)
    ended_at = Time.at(1629118924.508991)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006123] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006123] = id
  end
end
created_at = Time.at(1629042224.5949929)
updated_at = Time.at(1630493762.2866821)
started_at = Time.at(1630493444.4172218)
ended_at = Time.at(1630493745.766602)
obj_was = Game.where("id"=>50006124, "tournament_id"=>50000003, "seqno"=>38, "gname"=>"group1:1-3", "group_no"=>1, "table_no"=>2, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>38, "gname"=>"group1:1-3", "group_no"=>1, "table_no"=>2, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>38, "gname"=>"group1:1-3", "group_no"=>1, "table_no"=>2, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>38, "Spieler1"=>366548, "Spieler2"=>352853, "Ergebnis1"=>45, "Ergebnis2"=>60, "Aufnahmen1"=>13, "Aufnahmen2"=>13, "Höchstserie1"=>15, "Höchstserie2"=>21, "Tischnummer"=>2}}
    obj.data = data
    created_at = Time.at(1629042224.5949929)
    updated_at = Time.at(1630493762.2866821)
    started_at = Time.at(1630493444.4172218)
    ended_at = Time.at(1630493745.766602)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006124] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006124] = id
  end
end
created_at = Time.at(1629042224.605315)
updated_at = Time.at(1629120185.0390332)
started_at = Time.at(1629120097.7994812)
ended_at = Time.at(1629120182.356624)
obj_was = Game.where("id"=>50006125, "tournament_id"=>50000003, "seqno"=>7, "gname"=>"group1:1-4", "group_no"=>1, "table_no"=>4, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>7, "gname"=>"group1:1-4", "group_no"=>1, "table_no"=>4, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>7, "gname"=>"group1:1-4", "group_no"=>1, "table_no"=>4, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>7, "Spieler1"=>366548, "Spieler2"=>121340, "Ergebnis1"=>14, "Ergebnis2"=>32, "Aufnahmen1"=>6, "Aufnahmen2"=>6, "Höchstserie1"=>6, "Höchstserie2"=>9, "Tischnummer"=>4}}
    obj.data = data
    created_at = Time.at(1629042224.605315)
    updated_at = Time.at(1629120185.0390332)
    started_at = Time.at(1629120097.7994812)
    ended_at = Time.at(1629120182.356624)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006125] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006125] = id
  end
end
created_at = Time.at(1629042224.615537)
updated_at = Time.at(1629121017.293792)
started_at = Time.at(1629120861.321595)
ended_at = Time.at(1629121014.601544)
obj_was = Game.where("id"=>50006126, "tournament_id"=>50000003, "seqno"=>11, "gname"=>"group1:1-5", "group_no"=>1, "table_no"=>3, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>11, "gname"=>"group1:1-5", "group_no"=>1, "table_no"=>3, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>11, "gname"=>"group1:1-5", "group_no"=>1, "table_no"=>3, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>11, "Spieler1"=>366548, "Spieler2"=>224762, "Ergebnis1"=>16, "Ergebnis2"=>16, "Aufnahmen1"=>9, "Aufnahmen2"=>9, "Höchstserie1"=>2, "Höchstserie2"=>5, "Tischnummer"=>3}}
    obj.data = data
    created_at = Time.at(1629042224.615537)
    updated_at = Time.at(1629121017.293792)
    started_at = Time.at(1629120861.321595)
    ended_at = Time.at(1629121014.601544)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006126] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006126] = id
  end
end
created_at = Time.at(1629042224.6295092)
updated_at = Time.at(1629219232.66859)
started_at = Time.at(1629219158.702024)
ended_at = Time.at(1629219229.129366)
obj_was = Game.where("id"=>50006127, "tournament_id"=>50000003, "seqno"=>17, "gname"=>"group1:1-6", "group_no"=>1, "table_no"=>4, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>17, "gname"=>"group1:1-6", "group_no"=>1, "table_no"=>4, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>17, "gname"=>"group1:1-6", "group_no"=>1, "table_no"=>4, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>17, "Spieler1"=>366548, "Spieler2"=>239940, "Ergebnis1"=>19, "Ergebnis2"=>16, "Aufnahmen1"=>14, "Aufnahmen2"=>14, "Höchstserie1"=>7, "Höchstserie2"=>3, "Tischnummer"=>4}}
    obj.data = data
    created_at = Time.at(1629042224.6295092)
    updated_at = Time.at(1629219232.66859)
    started_at = Time.at(1629219158.702024)
    ended_at = Time.at(1629219229.129366)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006127] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006127] = id
  end
end
created_at = Time.at(1629042224.6432698)
updated_at = Time.at(1629042224.6432698)
obj_was = Game.where("id"=>50006128, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group1:1-7", "group_no"=>1, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group1:1-7", "group_no"=>1, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group1:1-7", "group_no"=>1, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042224.6432698)
    updated_at = Time.at(1629042224.6432698)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006128] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006128] = id
  end
end
created_at = Time.at(1629042224.6642702)
updated_at = Time.at(1630140766.931966)
started_at = Time.at(1630140590.544828)
ended_at = Time.at(1630140764.1023219)
obj_was = Game.where("id"=>50006129, "tournament_id"=>50000003, "seqno"=>35, "gname"=>"group1:1-8", "group_no"=>1, "table_no"=>4, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>35, "gname"=>"group1:1-8", "group_no"=>1, "table_no"=>4, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>35, "gname"=>"group1:1-8", "group_no"=>1, "table_no"=>4, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>35, "Spieler1"=>224758, "Spieler2"=>366548, "Ergebnis1"=>16, "Ergebnis2"=>49, "Aufnahmen1"=>16, "Aufnahmen2"=>16, "Höchstserie1"=>3, "Höchstserie2"=>17, "Tischnummer"=>4}}
    obj.data = data
    created_at = Time.at(1629042224.6642702)
    updated_at = Time.at(1630140766.931966)
    started_at = Time.at(1630140590.544828)
    ended_at = Time.at(1630140764.1023219)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006129] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006129] = id
  end
end
created_at = Time.at(1629042224.679585)
updated_at = Time.at(1629220080.01582)
started_at = Time.at(1629219892.089647)
ended_at = Time.at(1629220037.524904)
obj_was = Game.where("id"=>50006130, "tournament_id"=>50000003, "seqno"=>20, "gname"=>"group1:2-3", "group_no"=>1, "table_no"=>3, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>20, "gname"=>"group1:2-3", "group_no"=>1, "table_no"=>3, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>20, "gname"=>"group1:2-3", "group_no"=>1, "table_no"=>3, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>20, "Spieler1"=>121315, "Spieler2"=>352853, "Ergebnis1"=>60, "Ergebnis2"=>14, "Aufnahmen1"=>4, "Aufnahmen2"=>4, "Höchstserie1"=>36, "Höchstserie2"=>12, "Tischnummer"=>3}}
    obj.data = data
    created_at = Time.at(1629042224.679585)
    updated_at = Time.at(1629220080.01582)
    started_at = Time.at(1629219892.089647)
    ended_at = Time.at(1629220037.524904)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006130] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006130] = id
  end
end
created_at = Time.at(1629042224.699533)
updated_at = Time.at(1629120424.485755)
started_at = Time.at(1629120266.36726)
ended_at = Time.at(1629120401.325227)
obj_was = Game.where("id"=>50006131, "tournament_id"=>50000003, "seqno"=>8, "gname"=>"group1:2-4", "group_no"=>1, "table_no"=>4, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>8, "gname"=>"group1:2-4", "group_no"=>1, "table_no"=>4, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>8, "gname"=>"group1:2-4", "group_no"=>1, "table_no"=>4, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>8, "Spieler1"=>121315, "Spieler2"=>121340, "Ergebnis1"=>60, "Ergebnis2"=>30, "Aufnahmen1"=>5, "Aufnahmen2"=>5, "Höchstserie1"=>21, "Höchstserie2"=>13, "Tischnummer"=>4}}
    obj.data = data
    created_at = Time.at(1629042224.699533)
    updated_at = Time.at(1629120424.485755)
    started_at = Time.at(1629120266.36726)
    ended_at = Time.at(1629120401.325227)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006131] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006131] = id
  end
end
created_at = Time.at(1629042224.7132428)
updated_at = Time.at(1629123327.912978)
started_at = Time.at(1629123195.615776)
ended_at = Time.at(1629123325.4220622)
obj_was = Game.where("id"=>50006132, "tournament_id"=>50000003, "seqno"=>14, "gname"=>"group1:2-5", "group_no"=>1, "table_no"=>3, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>14, "gname"=>"group1:2-5", "group_no"=>1, "table_no"=>3, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>14, "gname"=>"group1:2-5", "group_no"=>1, "table_no"=>3, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>14, "Spieler1"=>121315, "Spieler2"=>224762, "Ergebnis1"=>47, "Ergebnis2"=>16, "Aufnahmen1"=>12, "Aufnahmen2"=>12, "Höchstserie1"=>32, "Höchstserie2"=>4, "Tischnummer"=>3}}
    obj.data = data
    created_at = Time.at(1629042224.7132428)
    updated_at = Time.at(1629123327.912978)
    started_at = Time.at(1629123195.615776)
    ended_at = Time.at(1629123325.4220622)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006132] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006132] = id
  end
end
created_at = Time.at(1629042224.73011)
updated_at = Time.at(1630490134.611125)
started_at = Time.at(1630300145.061706)
ended_at = Time.at(1630490134.609934)
obj_was = Game.where("id"=>50006133, "tournament_id"=>50000003, "seqno"=>37, "gname"=>"group1:2-6", "group_no"=>1, "table_no"=>4, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>37, "gname"=>"group1:2-6", "group_no"=>1, "table_no"=>4, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>37, "gname"=>"group1:2-6", "group_no"=>1, "table_no"=>4, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042224.73011)
    updated_at = Time.at(1630490134.611125)
    started_at = Time.at(1630300145.061706)
    ended_at = Time.at(1630490134.609934)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006133] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006133] = id
  end
end
created_at = Time.at(1629042224.7444968)
updated_at = Time.at(1629219707.5740511)
started_at = Time.at(1629219624.871238)
ended_at = Time.at(1629219704.889838)
obj_was = Game.where("id"=>50006134, "tournament_id"=>50000003, "seqno"=>19, "gname"=>"group1:2-7", "group_no"=>1, "table_no"=>1, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>19, "gname"=>"group1:2-7", "group_no"=>1, "table_no"=>1, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>19, "gname"=>"group1:2-7", "group_no"=>1, "table_no"=>1, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>19, "Spieler1"=>121315, "Spieler2"=>246783, "Ergebnis1"=>60, "Ergebnis2"=>5, "Aufnahmen1"=>11, "Aufnahmen2"=>11, "Höchstserie1"=>23, "Höchstserie2"=>3, "Tischnummer"=>1}}
    obj.data = data
    created_at = Time.at(1629042224.7444968)
    updated_at = Time.at(1629219707.5740511)
    started_at = Time.at(1629219624.871238)
    ended_at = Time.at(1629219704.889838)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006134] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006134] = id
  end
end
created_at = Time.at(1629042224.7572029)
updated_at = Time.at(1629119617.5928478)
started_at = Time.at(1629119357.002528)
ended_at = Time.at(1629119612.6844978)
obj_was = Game.where("id"=>50006135, "tournament_id"=>50000003, "seqno"=>1, "gname"=>"group1:2-8", "group_no"=>1, "table_no"=>1, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>1, "gname"=>"group1:2-8", "group_no"=>1, "table_no"=>1, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>1, "gname"=>"group1:2-8", "group_no"=>1, "table_no"=>1, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>1, "Spieler1"=>121315, "Spieler2"=>224758, "Ergebnis1"=>28, "Ergebnis2"=>16, "Aufnahmen1"=>17, "Aufnahmen2"=>17, "Höchstserie1"=>10, "Höchstserie2"=>4, "Tischnummer"=>1}}
    obj.data = data
    created_at = Time.at(1629042224.7572029)
    updated_at = Time.at(1629119617.5928478)
    started_at = Time.at(1629119357.002528)
    ended_at = Time.at(1629119612.6844978)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006135] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006135] = id
  end
end
created_at = Time.at(1629042224.7686532)
updated_at = Time.at(1629120595.251711)
started_at = Time.at(1629120469.51734)
ended_at = Time.at(1629120592.671226)
obj_was = Game.where("id"=>50006136, "tournament_id"=>50000003, "seqno"=>9, "gname"=>"group1:3-4", "group_no"=>1, "table_no"=>4, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>9, "gname"=>"group1:3-4", "group_no"=>1, "table_no"=>4, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>9, "gname"=>"group1:3-4", "group_no"=>1, "table_no"=>4, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>9, "Spieler1"=>352853, "Spieler2"=>121340, "Ergebnis1"=>11, "Ergebnis2"=>32, "Aufnahmen1"=>10, "Aufnahmen2"=>10, "Höchstserie1"=>3, "Höchstserie2"=>16, "Tischnummer"=>4}}
    obj.data = data
    created_at = Time.at(1629042224.7686532)
    updated_at = Time.at(1629120595.251711)
    started_at = Time.at(1629120469.51734)
    ended_at = Time.at(1629120592.671226)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006136] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006136] = id
  end
end
created_at = Time.at(1629042224.7862232)
updated_at = Time.at(1629118518.292923)
started_at = Time.at(1629118411.648917)
ended_at = Time.at(1629118511.473739)
obj_was = Game.where("id"=>50006137, "tournament_id"=>50000003, "seqno"=>2, "gname"=>"group1:3-5", "group_no"=>1, "table_no"=>1, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>2, "gname"=>"group1:3-5", "group_no"=>1, "table_no"=>1, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>2, "gname"=>"group1:3-5", "group_no"=>1, "table_no"=>1, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>2, "Spieler1"=>352853, "Spieler2"=>224762, "Ergebnis1"=>48, "Ergebnis2"=>16, "Aufnahmen1"=>14, "Aufnahmen2"=>14, "Höchstserie1"=>14, "Höchstserie2"=>6, "Tischnummer"=>1}}
    obj.data = data
    created_at = Time.at(1629042224.7862232)
    updated_at = Time.at(1629118518.292923)
    started_at = Time.at(1629118411.648917)
    ended_at = Time.at(1629118511.473739)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006137] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006137] = id
  end
end
created_at = Time.at(1629042224.809223)
updated_at = Time.at(1629123610.990758)
started_at = Time.at(1629123497.025198)
ended_at = Time.at(1629123608.8157282)
obj_was = Game.where("id"=>50006138, "tournament_id"=>50000003, "seqno"=>15, "gname"=>"group1:3-6", "group_no"=>1, "table_no"=>3, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>15, "gname"=>"group1:3-6", "group_no"=>1, "table_no"=>3, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>15, "gname"=>"group1:3-6", "group_no"=>1, "table_no"=>3, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>15, "Spieler1"=>352853, "Spieler2"=>239940, "Ergebnis1"=>39, "Ergebnis2"=>16, "Aufnahmen1"=>10, "Aufnahmen2"=>10, "Höchstserie1"=>10, "Höchstserie2"=>4, "Tischnummer"=>3}}
    obj.data = data
    created_at = Time.at(1629042224.809223)
    updated_at = Time.at(1629123610.990758)
    started_at = Time.at(1629123497.025198)
    ended_at = Time.at(1629123608.8157282)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006138] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006138] = id
  end
end
created_at = Time.at(1629042224.8216078)
updated_at = Time.at(1629042224.8216078)
obj_was = Game.where("id"=>50006139, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group1:3-7", "group_no"=>1, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group1:3-7", "group_no"=>1, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group1:3-7", "group_no"=>1, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042224.8216078)
    updated_at = Time.at(1629042224.8216078)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006139] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006139] = id
  end
end
created_at = Time.at(1629042224.836873)
updated_at = Time.at(1630140533.72132)
started_at = Time.at(1630140419.211374)
ended_at = Time.at(1630140529.7846808)
obj_was = Game.where("id"=>50006140, "tournament_id"=>50000003, "seqno"=>34, "gname"=>"group1:3-8", "group_no"=>1, "table_no"=>4, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>34, "gname"=>"group1:3-8", "group_no"=>1, "table_no"=>4, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>34, "gname"=>"group1:3-8", "group_no"=>1, "table_no"=>4, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>34, "Spieler1"=>224758, "Spieler2"=>352853, "Ergebnis1"=>16, "Ergebnis2"=>9, "Aufnahmen1"=>6, "Aufnahmen2"=>6, "Höchstserie1"=>8, "Höchstserie2"=>3, "Tischnummer"=>4}}
    obj.data = data
    created_at = Time.at(1629042224.836873)
    updated_at = Time.at(1630140533.72132)
    started_at = Time.at(1630140419.211374)
    ended_at = Time.at(1630140529.7846808)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006140] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006140] = id
  end
end
created_at = Time.at(1629042224.855948)
updated_at = Time.at(1629123140.57486)
started_at = Time.at(1629123057.203555)
ended_at = Time.at(1629123130.8132339)
obj_was = Game.where("id"=>50006141, "tournament_id"=>50000003, "seqno"=>13, "gname"=>"group1:4-5", "group_no"=>1, "table_no"=>4, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>13, "gname"=>"group1:4-5", "group_no"=>1, "table_no"=>4, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>13, "gname"=>"group1:4-5", "group_no"=>1, "table_no"=>4, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>13, "Spieler1"=>121340, "Spieler2"=>224762, "Ergebnis1"=>5, "Ergebnis2"=>16, "Aufnahmen1"=>9, "Aufnahmen2"=>9, "Höchstserie1"=>1, "Höchstserie2"=>5, "Tischnummer"=>4}}
    obj.data = data
    created_at = Time.at(1629042224.855948)
    updated_at = Time.at(1629123140.57486)
    started_at = Time.at(1629123057.203555)
    ended_at = Time.at(1629123130.8132339)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006141] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006141] = id
  end
end
created_at = Time.at(1629042224.877961)
updated_at = Time.at(1629120791.078043)
started_at = Time.at(1629120652.19105)
ended_at = Time.at(1629120788.731755)
obj_was = Game.where("id"=>50006142, "tournament_id"=>50000003, "seqno"=>10, "gname"=>"group1:4-6", "group_no"=>1, "table_no"=>2, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>10, "gname"=>"group1:4-6", "group_no"=>1, "table_no"=>2, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>10, "gname"=>"group1:4-6", "group_no"=>1, "table_no"=>2, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>10, "Spieler1"=>121340, "Spieler2"=>239940, "Ergebnis1"=>32, "Ergebnis2"=>5, "Aufnahmen1"=>6, "Aufnahmen2"=>6, "Höchstserie1"=>8, "Höchstserie2"=>2, "Tischnummer"=>2}}
    obj.data = data
    created_at = Time.at(1629042224.877961)
    updated_at = Time.at(1629120791.078043)
    started_at = Time.at(1629120652.19105)
    ended_at = Time.at(1629120788.731755)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006142] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006142] = id
  end
end
created_at = Time.at(1629042224.8969212)
updated_at = Time.at(1629042224.8969212)
obj_was = Game.where("id"=>50006143, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group1:4-7", "group_no"=>1, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group1:4-7", "group_no"=>1, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group1:4-7", "group_no"=>1, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042224.8969212)
    updated_at = Time.at(1629042224.8969212)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006143] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006143] = id
  end
end
created_at = Time.at(1629042224.915145)
updated_at = Time.at(1630140934.606417)
started_at = Time.at(1630140794.243551)
ended_at = Time.at(1630140924.320977)
obj_was = Game.where("id"=>50006144, "tournament_id"=>50000003, "seqno"=>36, "gname"=>"group1:4-8", "group_no"=>1, "table_no"=>4, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>36, "gname"=>"group1:4-8", "group_no"=>1, "table_no"=>4, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>36, "gname"=>"group1:4-8", "group_no"=>1, "table_no"=>4, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>36, "Spieler1"=>224758, "Spieler2"=>121340, "Ergebnis1"=>16, "Ergebnis2"=>16, "Aufnahmen1"=>6, "Aufnahmen2"=>6, "Höchstserie1"=>4, "Höchstserie2"=>12, "Tischnummer"=>4}}
    obj.data = data
    created_at = Time.at(1629042224.915145)
    updated_at = Time.at(1630140934.606417)
    started_at = Time.at(1630140794.243551)
    ended_at = Time.at(1630140924.320977)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006144] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006144] = id
  end
end
created_at = Time.at(1629042224.935217)
updated_at = Time.at(1629122480.7974699)
started_at = Time.at(1629121221.171324)
ended_at = Time.at(1629122480.797027)
obj_was = Game.where("id"=>50006145, "tournament_id"=>50000003, "seqno"=>12, "gname"=>"group1:5-6", "group_no"=>1, "table_no"=>4, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>12, "gname"=>"group1:5-6", "group_no"=>1, "table_no"=>4, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>12, "gname"=>"group1:5-6", "group_no"=>1, "table_no"=>4, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>12, "Spieler1"=>224762, "Spieler2"=>239940, "Ergebnis1"=>16, "Ergebnis2"=>4, "Aufnahmen1"=>7, "Aufnahmen2"=>7, "Höchstserie1"=>4, "Höchstserie2"=>2, "Tischnummer"=>4}}
    obj.data = data
    created_at = Time.at(1629042224.935217)
    updated_at = Time.at(1629122480.7974699)
    started_at = Time.at(1629121221.171324)
    ended_at = Time.at(1629122480.797027)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006145] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006145] = id
  end
end
created_at = Time.at(1629042224.950162)
updated_at = Time.at(1629219496.373495)
started_at = Time.at(1629219440.215723)
ended_at = Time.at(1629219493.4513931)
obj_was = Game.where("id"=>50006146, "tournament_id"=>50000003, "seqno"=>18, "gname"=>"group1:5-7", "group_no"=>1, "table_no"=>1, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>18, "gname"=>"group1:5-7", "group_no"=>1, "table_no"=>1, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>18, "gname"=>"group1:5-7", "group_no"=>1, "table_no"=>1, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>18, "Spieler1"=>224762, "Spieler2"=>246783, "Ergebnis1"=>16, "Ergebnis2"=>10, "Aufnahmen1"=>10, "Aufnahmen2"=>10, "Höchstserie1"=>6, "Höchstserie2"=>5, "Tischnummer"=>1}}
    obj.data = data
    created_at = Time.at(1629042224.950162)
    updated_at = Time.at(1629219496.373495)
    started_at = Time.at(1629219440.215723)
    ended_at = Time.at(1629219493.4513931)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006146] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006146] = id
  end
end
created_at = Time.at(1629042224.976367)
updated_at = Time.at(1629119284.618997)
started_at = Time.at(1629119143.232468)
ended_at = Time.at(1629119278.286637)
obj_was = Game.where("id"=>50006147, "tournament_id"=>50000003, "seqno"=>4, "gname"=>"group1:5-8", "group_no"=>1, "table_no"=>4, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>4, "gname"=>"group1:5-8", "group_no"=>1, "table_no"=>4, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>4, "gname"=>"group1:5-8", "group_no"=>1, "table_no"=>4, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>4, "Spieler1"=>224762, "Spieler2"=>224758, "Ergebnis1"=>11, "Ergebnis2"=>16, "Aufnahmen1"=>11, "Aufnahmen2"=>11, "Höchstserie1"=>4, "Höchstserie2"=>2, "Tischnummer"=>4}}
    obj.data = data
    created_at = Time.at(1629042224.976367)
    updated_at = Time.at(1629119284.618997)
    started_at = Time.at(1629119143.232468)
    ended_at = Time.at(1629119278.286637)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006147] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006147] = id
  end
end
created_at = Time.at(1629042224.991553)
updated_at = Time.at(1629124573.879429)
started_at = Time.at(1629123709.690285)
ended_at = Time.at(1629124571.376281)
obj_was = Game.where("id"=>50006148, "tournament_id"=>50000003, "seqno"=>16, "gname"=>"group1:6-7", "group_no"=>1, "table_no"=>3, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>16, "gname"=>"group1:6-7", "group_no"=>1, "table_no"=>3, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>16, "gname"=>"group1:6-7", "group_no"=>1, "table_no"=>3, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>16, "Spieler1"=>239940, "Spieler2"=>246783, "Ergebnis1"=>16, "Ergebnis2"=>5, "Aufnahmen1"=>14, "Aufnahmen2"=>14, "Höchstserie1"=>6, "Höchstserie2"=>2, "Tischnummer"=>3}}
    obj.data = data
    created_at = Time.at(1629042224.991553)
    updated_at = Time.at(1629124573.879429)
    started_at = Time.at(1629123709.690285)
    ended_at = Time.at(1629124571.376281)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006148] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006148] = id
  end
end
created_at = Time.at(1629042225.0091279)
updated_at = Time.at(1629119789.917003)
started_at = Time.at(1629119678.071923)
ended_at = Time.at(1629119787.155169)
obj_was = Game.where("id"=>50006149, "tournament_id"=>50000003, "seqno"=>5, "gname"=>"group1:6-8", "group_no"=>1, "table_no"=>1, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>5, "gname"=>"group1:6-8", "group_no"=>1, "table_no"=>1, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>5, "gname"=>"group1:6-8", "group_no"=>1, "table_no"=>1, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>5, "Spieler1"=>239940, "Spieler2"=>224758, "Ergebnis1"=>16, "Ergebnis2"=>3, "Aufnahmen1"=>7, "Aufnahmen2"=>7, "Höchstserie1"=>3, "Höchstserie2"=>1, "Tischnummer"=>1}}
    obj.data = data
    created_at = Time.at(1629042225.0091279)
    updated_at = Time.at(1629119789.917003)
    started_at = Time.at(1629119678.071923)
    ended_at = Time.at(1629119787.155169)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006149] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006149] = id
  end
end
created_at = Time.at(1629042225.0350661)
updated_at = Time.at(1629119963.22963)
started_at = Time.at(1629119888.824067)
ended_at = Time.at(1629119960.925081)
obj_was = Game.where("id"=>50006150, "tournament_id"=>50000003, "seqno"=>6, "gname"=>"group1:7-8", "group_no"=>1, "table_no"=>4, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>6, "gname"=>"group1:7-8", "group_no"=>1, "table_no"=>4, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>6, "gname"=>"group1:7-8", "group_no"=>1, "table_no"=>4, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>6, "Spieler1"=>246783, "Spieler2"=>224758, "Ergebnis1"=>7, "Ergebnis2"=>16, "Aufnahmen1"=>15, "Aufnahmen2"=>15, "Höchstserie1"=>4, "Höchstserie2"=>3, "Tischnummer"=>4}}
    obj.data = data
    created_at = Time.at(1629042225.0350661)
    updated_at = Time.at(1629119963.22963)
    started_at = Time.at(1629119888.824067)
    ended_at = Time.at(1629119960.925081)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006150] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006150] = id
  end
end
created_at = Time.at(1629042225.052278)
updated_at = Time.at(1629042225.052278)
obj_was = Game.where("id"=>50006151, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-2", "group_no"=>2, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-2", "group_no"=>2, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-2", "group_no"=>2, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042225.052278)
    updated_at = Time.at(1629042225.052278)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006151] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006151] = id
  end
end
created_at = Time.at(1629042225.077962)
updated_at = Time.at(1629042225.077962)
obj_was = Game.where("id"=>50006152, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-3", "group_no"=>2, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-3", "group_no"=>2, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-3", "group_no"=>2, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042225.077962)
    updated_at = Time.at(1629042225.077962)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006152] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006152] = id
  end
end
created_at = Time.at(1629042225.0925581)
updated_at = Time.at(1629042225.0925581)
obj_was = Game.where("id"=>50006153, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-4", "group_no"=>2, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-4", "group_no"=>2, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-4", "group_no"=>2, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042225.0925581)
    updated_at = Time.at(1629042225.0925581)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006153] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006153] = id
  end
end
created_at = Time.at(1629042225.111337)
updated_at = Time.at(1629042225.111337)
obj_was = Game.where("id"=>50006154, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-5", "group_no"=>2, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-5", "group_no"=>2, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-5", "group_no"=>2, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042225.111337)
    updated_at = Time.at(1629042225.111337)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006154] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006154] = id
  end
end
created_at = Time.at(1629042225.133078)
updated_at = Time.at(1629042225.133078)
obj_was = Game.where("id"=>50006155, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-6", "group_no"=>2, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-6", "group_no"=>2, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-6", "group_no"=>2, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042225.133078)
    updated_at = Time.at(1629042225.133078)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006155] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006155] = id
  end
end
created_at = Time.at(1629042225.1480231)
updated_at = Time.at(1629042225.1480231)
obj_was = Game.where("id"=>50006156, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-7", "group_no"=>2, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-7", "group_no"=>2, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-7", "group_no"=>2, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042225.1480231)
    updated_at = Time.at(1629042225.1480231)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006156] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006156] = id
  end
end
created_at = Time.at(1629042225.183966)
updated_at = Time.at(1629042225.183966)
obj_was = Game.where("id"=>50006157, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-8", "group_no"=>2, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-8", "group_no"=>2, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:1-8", "group_no"=>2, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042225.183966)
    updated_at = Time.at(1629042225.183966)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006157] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006157] = id
  end
end
created_at = Time.at(1629042225.2053492)
updated_at = Time.at(1629221133.0066838)
started_at = Time.at(1629221060.133791)
ended_at = Time.at(1629221128.933333)
obj_was = Game.where("id"=>50006158, "tournament_id"=>50000003, "seqno"=>22, "gname"=>"group2:2-3", "group_no"=>2, "table_no"=>2, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>22, "gname"=>"group2:2-3", "group_no"=>2, "table_no"=>2, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>22, "gname"=>"group2:2-3", "group_no"=>2, "table_no"=>2, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>2, "Partie"=>22, "Spieler1"=>121341, "Spieler2"=>121329, "Ergebnis1"=>84, "Ergebnis2"=>60, "Aufnahmen1"=>7, "Aufnahmen2"=>7, "Höchstserie1"=>55, "Höchstserie2"=>21, "Tischnummer"=>2}}
    obj.data = data
    created_at = Time.at(1629042225.2053492)
    updated_at = Time.at(1629221133.0066838)
    started_at = Time.at(1629221060.133791)
    ended_at = Time.at(1629221128.933333)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006158] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006158] = id
  end
end
created_at = Time.at(1629042225.2232609)
updated_at = Time.at(1629220344.6238)
started_at = Time.at(1629220172.8556008)
ended_at = Time.at(1629220341.717845)
obj_was = Game.where("id"=>50006159, "tournament_id"=>50000003, "seqno"=>21, "gname"=>"group2:2-4", "group_no"=>2, "table_no"=>2, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>21, "gname"=>"group2:2-4", "group_no"=>2, "table_no"=>2, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>21, "gname"=>"group2:2-4", "group_no"=>2, "table_no"=>2, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>2, "Partie"=>21, "Spieler1"=>121341, "Spieler2"=>352025, "Ergebnis1"=>70, "Ergebnis2"=>32, "Aufnahmen1"=>15, "Aufnahmen2"=>15, "Höchstserie1"=>20, "Höchstserie2"=>6, "Tischnummer"=>2}}
    obj.data = data
    created_at = Time.at(1629042225.2232609)
    updated_at = Time.at(1629220344.6238)
    started_at = Time.at(1629220172.8556008)
    ended_at = Time.at(1629220341.717845)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006159] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006159] = id
  end
end
created_at = Time.at(1629042225.235498)
updated_at = Time.at(1629221405.715644)
started_at = Time.at(1629221207.0985332)
ended_at = Time.at(1629221403.019855)
obj_was = Game.where("id"=>50006160, "tournament_id"=>50000003, "seqno"=>23, "gname"=>"group2:2-5", "group_no"=>2, "table_no"=>3, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>23, "gname"=>"group2:2-5", "group_no"=>2, "table_no"=>3, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>23, "gname"=>"group2:2-5", "group_no"=>2, "table_no"=>3, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>2, "Partie"=>23, "Spieler1"=>121341, "Spieler2"=>nil, "Ergebnis1"=>150, "Ergebnis2"=>14, "Aufnahmen1"=>18, "Aufnahmen2"=>18, "Höchstserie1"=>51, "Höchstserie2"=>4, "Tischnummer"=>3}}
    obj.data = data
    created_at = Time.at(1629042225.235498)
    updated_at = Time.at(1629221405.715644)
    started_at = Time.at(1629221207.0985332)
    ended_at = Time.at(1629221403.019855)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006160] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006160] = id
  end
end
created_at = Time.at(1629042225.2553852)
updated_at = Time.at(1629224337.9299278)
started_at = Time.at(1629224221.1528971)
ended_at = Time.at(1629224330.0831082)
obj_was = Game.where("id"=>50006161, "tournament_id"=>50000003, "seqno"=>24, "gname"=>"group2:2-6", "group_no"=>2, "table_no"=>3, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>24, "gname"=>"group2:2-6", "group_no"=>2, "table_no"=>3, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>24, "gname"=>"group2:2-6", "group_no"=>2, "table_no"=>3, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>2, "Partie"=>24, "Spieler1"=>121341, "Spieler2"=>356386, "Ergebnis1"=>147, "Ergebnis2"=>16, "Aufnahmen1"=>22, "Aufnahmen2"=>22, "Höchstserie1"=>21, "Höchstserie2"=>2, "Tischnummer"=>3}}
    obj.data = data
    created_at = Time.at(1629042225.2553852)
    updated_at = Time.at(1629224337.9299278)
    started_at = Time.at(1629224221.1528971)
    ended_at = Time.at(1629224330.0831082)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006161] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006161] = id
  end
end
created_at = Time.at(1629042225.277768)
updated_at = Time.at(1629042225.277768)
obj_was = Game.where("id"=>50006162, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:2-7", "group_no"=>2, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:2-7", "group_no"=>2, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:2-7", "group_no"=>2, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042225.277768)
    updated_at = Time.at(1629042225.277768)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006162] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006162] = id
  end
end
created_at = Time.at(1629042225.298002)
updated_at = Time.at(1629225078.441216)
started_at = Time.at(1629224938.776683)
ended_at = Time.at(1629225073.702776)
obj_was = Game.where("id"=>50006163, "tournament_id"=>50000003, "seqno"=>26, "gname"=>"group2:2-8", "group_no"=>2, "table_no"=>3, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>26, "gname"=>"group2:2-8", "group_no"=>2, "table_no"=>3, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>26, "gname"=>"group2:2-8", "group_no"=>2, "table_no"=>3, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>2, "Partie"=>26, "Spieler1"=>121341, "Spieler2"=>352574, "Ergebnis1"=>78, "Ergebnis2"=>32, "Aufnahmen1"=>10, "Aufnahmen2"=>10, "Höchstserie1"=>32, "Höchstserie2"=>11, "Tischnummer"=>3}}
    obj.data = data
    created_at = Time.at(1629042225.298002)
    updated_at = Time.at(1629225078.441216)
    started_at = Time.at(1629224938.776683)
    ended_at = Time.at(1629225073.702776)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006163] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006163] = id
  end
end
created_at = Time.at(1629042225.315656)
updated_at = Time.at(1629225498.568203)
started_at = Time.at(1629225257.816051)
ended_at = Time.at(1629225496.435724)
obj_was = Game.where("id"=>50006164, "tournament_id"=>50000003, "seqno"=>28, "gname"=>"group2:3-4", "group_no"=>2, "table_no"=>2, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>28, "gname"=>"group2:3-4", "group_no"=>2, "table_no"=>2, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>28, "gname"=>"group2:3-4", "group_no"=>2, "table_no"=>2, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>2, "Partie"=>28, "Spieler1"=>121329, "Spieler2"=>352025, "Ergebnis1"=>30, "Ergebnis2"=>32, "Aufnahmen1"=>10, "Aufnahmen2"=>10, "Höchstserie1"=>11, "Höchstserie2"=>10, "Tischnummer"=>2}}
    obj.data = data
    created_at = Time.at(1629042225.315656)
    updated_at = Time.at(1629225498.568203)
    started_at = Time.at(1629225257.816051)
    ended_at = Time.at(1629225496.435724)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006164] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006164] = id
  end
end
created_at = Time.at(1629042225.330106)
updated_at = Time.at(1629226521.702843)
started_at = Time.at(1629226387.3510242)
ended_at = Time.at(1629226518.602559)
obj_was = Game.where("id"=>50006165, "tournament_id"=>50000003, "seqno"=>32, "gname"=>"group2:3-5", "group_no"=>2, "table_no"=>3, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>32, "gname"=>"group2:3-5", "group_no"=>2, "table_no"=>3, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>32, "gname"=>"group2:3-5", "group_no"=>2, "table_no"=>3, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>2, "Partie"=>32, "Spieler1"=>121329, "Spieler2"=>nil, "Ergebnis1"=>60, "Ergebnis2"=>15, "Aufnahmen1"=>14, "Aufnahmen2"=>14, "Höchstserie1"=>28, "Höchstserie2"=>5, "Tischnummer"=>3}}
    obj.data = data
    created_at = Time.at(1629042225.330106)
    updated_at = Time.at(1629226521.702843)
    started_at = Time.at(1629226387.3510242)
    ended_at = Time.at(1629226518.602559)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006165] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006165] = id
  end
end
created_at = Time.at(1629042225.345601)
updated_at = Time.at(1629224933.982922)
obj_was = Game.where("id"=>50006166, "tournament_id"=>50000003, "seqno"=>27, "gname"=>"group2:3-6", "group_no"=>2, "table_no"=>3, "round_no"=>1, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>27, "gname"=>"group2:3-6", "group_no"=>2, "table_no"=>3, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>27, "gname"=>"group2:3-6", "group_no"=>2, "table_no"=>3, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"tmp_results"=>{"playera"=>{"result"=>0, "innings"=>0, "innings_list"=>[], "innings_redo_list"=>[], "hs"=>0, "gd"=>0.0, "balls_goal"=>60, "tc"=>0}, "playerb"=>{"result"=>0, "innings"=>0, "innings_list"=>[], "innings_redo_list"=>[], "hs"=>0, "gd"=>0.0, "balls_goal"=>16, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "state"=>"game_setup_started"}}
    obj.data = data
    created_at = Time.at(1629042225.345601)
    updated_at = Time.at(1629224933.982922)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006166] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006166] = id
  end
end
created_at = Time.at(1629042225.365549)
updated_at = Time.at(1629042225.365549)
obj_was = Game.where("id"=>50006167, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:3-7", "group_no"=>2, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:3-7", "group_no"=>2, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:3-7", "group_no"=>2, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042225.365549)
    updated_at = Time.at(1629042225.365549)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006167] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006167] = id
  end
end
created_at = Time.at(1629042225.37953)
updated_at = Time.at(1629226333.439426)
started_at = Time.at(1629226175.930356)
ended_at = Time.at(1629226331.252477)
obj_was = Game.where("id"=>50006168, "tournament_id"=>50000003, "seqno"=>31, "gname"=>"group2:3-8", "group_no"=>2, "table_no"=>2, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>31, "gname"=>"group2:3-8", "group_no"=>2, "table_no"=>2, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>31, "gname"=>"group2:3-8", "group_no"=>2, "table_no"=>2, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>2, "Partie"=>31, "Spieler1"=>121329, "Spieler2"=>352574, "Ergebnis1"=>23, "Ergebnis2"=>32, "Aufnahmen1"=>10, "Aufnahmen2"=>10, "Höchstserie1"=>6, "Höchstserie2"=>9, "Tischnummer"=>2}}
    obj.data = data
    created_at = Time.at(1629042225.37953)
    updated_at = Time.at(1629226333.439426)
    started_at = Time.at(1629226175.930356)
    ended_at = Time.at(1629226331.252477)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006168] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006168] = id
  end
end
created_at = Time.at(1629042225.399796)
updated_at = Time.at(1629225745.979713)
started_at = Time.at(1629225578.7102668)
ended_at = Time.at(1629225743.594624)
obj_was = Game.where("id"=>50006169, "tournament_id"=>50000003, "seqno"=>29, "gname"=>"group2:4-5", "group_no"=>2, "table_no"=>2, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>29, "gname"=>"group2:4-5", "group_no"=>2, "table_no"=>2, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>29, "gname"=>"group2:4-5", "group_no"=>2, "table_no"=>2, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>2, "Partie"=>29, "Spieler1"=>352025, "Spieler2"=>nil, "Ergebnis1"=>9, "Ergebnis2"=>16, "Aufnahmen1"=>6, "Aufnahmen2"=>6, "Höchstserie1"=>3, "Höchstserie2"=>10, "Tischnummer"=>2}}
    obj.data = data
    created_at = Time.at(1629042225.399796)
    updated_at = Time.at(1629225745.979713)
    started_at = Time.at(1629225578.7102668)
    ended_at = Time.at(1629225743.594624)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006169] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006169] = id
  end
end
created_at = Time.at(1629042225.4124138)
updated_at = Time.at(1629042225.4124138)
obj_was = Game.where("id"=>50006170, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:4-6", "group_no"=>2, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:4-6", "group_no"=>2, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:4-6", "group_no"=>2, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042225.4124138)
    updated_at = Time.at(1629042225.4124138)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006170] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006170] = id
  end
end
created_at = Time.at(1629042225.4262831)
updated_at = Time.at(1629042225.4262831)
obj_was = Game.where("id"=>50006171, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:4-7", "group_no"=>2, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:4-7", "group_no"=>2, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:4-7", "group_no"=>2, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042225.4262831)
    updated_at = Time.at(1629042225.4262831)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006171] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006171] = id
  end
end
created_at = Time.at(1629042225.441448)
updated_at = Time.at(1629225973.289875)
started_at = Time.at(1629225908.4358442)
ended_at = Time.at(1629225971.382668)
obj_was = Game.where("id"=>50006172, "tournament_id"=>50000003, "seqno"=>30, "gname"=>"group2:4-8", "group_no"=>2, "table_no"=>2, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>30, "gname"=>"group2:4-8", "group_no"=>2, "table_no"=>2, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>30, "gname"=>"group2:4-8", "group_no"=>2, "table_no"=>2, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>2, "Partie"=>30, "Spieler1"=>352025, "Spieler2"=>352574, "Ergebnis1"=>32, "Ergebnis2"=>4, "Aufnahmen1"=>7, "Aufnahmen2"=>7, "Höchstserie1"=>9, "Höchstserie2"=>3, "Tischnummer"=>2}}
    obj.data = data
    created_at = Time.at(1629042225.441448)
    updated_at = Time.at(1629225973.289875)
    started_at = Time.at(1629225908.4358442)
    ended_at = Time.at(1629225971.382668)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006172] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006172] = id
  end
end
created_at = Time.at(1629042225.459009)
updated_at = Time.at(1629042225.459009)
obj_was = Game.where("id"=>50006173, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:5-6", "group_no"=>2, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:5-6", "group_no"=>2, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:5-6", "group_no"=>2, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042225.459009)
    updated_at = Time.at(1629042225.459009)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006173] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006173] = id
  end
end
created_at = Time.at(1629042225.472137)
updated_at = Time.at(1629224885.16356)
obj_was = Game.where("id"=>50006174, "tournament_id"=>50000003, "seqno"=>25, "gname"=>"group2:5-7", "group_no"=>2, "table_no"=>3, "round_no"=>1, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>25, "gname"=>"group2:5-7", "group_no"=>2, "table_no"=>3, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>25, "gname"=>"group2:5-7", "group_no"=>2, "table_no"=>3, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"tmp_results"=>{"playera"=>{"result"=>0, "innings"=>0, "innings_list"=>[], "innings_redo_list"=>[], "hs"=>0, "gd"=>0.0, "balls_goal"=>16, "tc"=>0}, "playerb"=>{"result"=>0, "innings"=>0, "innings_list"=>[], "innings_redo_list"=>[], "hs"=>0, "gd"=>0.0, "balls_goal"=>16, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>2, "Partie"=>24, "Spieler1"=>121341, "Spieler2"=>356386, "Ergebnis1"=>147, "Ergebnis2"=>16, "Aufnahmen1"=>22, "Aufnahmen2"=>22, "Höchstserie1"=>21, "Höchstserie2"=>2, "Tischnummer"=>3}, "state"=>"game_shootout_started"}}
    obj.data = data
    created_at = Time.at(1629042225.472137)
    updated_at = Time.at(1629224885.16356)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006174] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006174] = id
  end
end
created_at = Time.at(1629042225.483708)
updated_at = Time.at(1629226680.849836)
started_at = Time.at(1629226561.199384)
ended_at = Time.at(1629226678.827232)
obj_was = Game.where("id"=>50006175, "tournament_id"=>50000003, "seqno"=>33, "gname"=>"group2:5-8", "group_no"=>2, "table_no"=>3, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>33, "gname"=>"group2:5-8", "group_no"=>2, "table_no"=>3, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>33, "gname"=>"group2:5-8", "group_no"=>2, "table_no"=>3, "round_no"=>1)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"ba_results"=>{"Gruppe"=>2, "Partie"=>33, "Spieler1"=>nil, "Spieler2"=>352574, "Ergebnis1"=>12, "Ergebnis2"=>32, "Aufnahmen1"=>16, "Aufnahmen2"=>16, "Höchstserie1"=>4, "Höchstserie2"=>10, "Tischnummer"=>3}}
    obj.data = data
    created_at = Time.at(1629042225.483708)
    updated_at = Time.at(1629226680.849836)
    started_at = Time.at(1629226561.199384)
    ended_at = Time.at(1629226678.827232)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006175] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006175] = id
  end
end
created_at = Time.at(1629042225.503762)
updated_at = Time.at(1629042225.503762)
obj_was = Game.where("id"=>50006176, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:6-7", "group_no"=>2, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:6-7", "group_no"=>2, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:6-7", "group_no"=>2, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042225.503762)
    updated_at = Time.at(1629042225.503762)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006176] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006176] = id
  end
end
created_at = Time.at(1629042225.5238988)
updated_at = Time.at(1629042225.5238988)
obj_was = Game.where("id"=>50006177, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:6-8", "group_no"=>2, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:6-8", "group_no"=>2, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:6-8", "group_no"=>2, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042225.5238988)
    updated_at = Time.at(1629042225.5238988)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006177] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006177] = id
  end
end
created_at = Time.at(1629042225.5416498)
updated_at = Time.at(1629042225.5416498)
obj_was = Game.where("id"=>50006178, "tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:7-8", "group_no"=>2, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:7-8", "group_no"=>2, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>50000003, "seqno"=>nil, "gname"=>"group2:7-8", "group_no"=>2, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    created_at = Time.at(1629042225.5416498)
    updated_at = Time.at(1629042225.5416498)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006178] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006178] = id
  end
end
created_at = Time.at(1629225094.798707)
updated_at = Time.at(1629225238.557421)
obj_was = Game.where("id"=>50006179, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    data = {"tmp_results"=>{"playera"=>{"result"=>0, "innings"=>0, "innings_list"=>[], "innings_redo_list"=>[], "hs"=>0, "gd"=>0.0, "balls_goal"=>nil, "tc"=>0}, "playerb"=>{"result"=>0, "innings"=>0, "innings_list"=>[], "innings_redo_list"=>[], "hs"=>0, "gd"=>0.0, "balls_goal"=>nil, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>2, "Partie"=>24, "Spieler1"=>121341, "Spieler2"=>356386, "Ergebnis1"=>141, "Ergebnis2"=>14, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>21, "Höchstserie2"=>2, "Tischnummer"=>2}, "state"=>"game_setup_started"}}
    obj.data = data
    created_at = Time.at(1629225094.798707)
    updated_at = Time.at(1629225238.557421)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006179] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006179] = id
  end
end
created_at = Time.at(1629666567.3792179)
updated_at = Time.at(1629666567.3792179)
obj_was = Game.where("id"=>50006201, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1629666567.3792179)
    updated_at = Time.at(1629666567.3792179)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006201] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006201] = id
  end
end
created_at = Time.at(1629666608.674059)
updated_at = Time.at(1629666608.674059)
obj_was = Game.where("id"=>50006202, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1629666608.674059)
    updated_at = Time.at(1629666608.674059)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006202] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006202] = id
  end
end
created_at = Time.at(1629666889.257459)
updated_at = Time.at(1629666911.3107798)
started_at = Time.at(1629666911.3103821)
obj_was = Game.where("id"=>50006203, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, started_at: started_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1629666889.257459)
    updated_at = Time.at(1629666911.3107798)
    started_at = Time.at(1629666911.3103821)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006203] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006203] = id
  end
end
created_at = Time.at(1629675848.197403)
updated_at = Time.at(1629675848.197403)
obj_was = Game.where("id"=>50006204, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1629675848.197403)
    updated_at = Time.at(1629675848.197403)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006204] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006204] = id
  end
end
created_at = Time.at(1630055286.288277)
updated_at = Time.at(1630055329.5910301)
started_at = Time.at(1630055310.17231)
ended_at = Time.at(1630055329.590471)
obj_was = Game.where("id"=>50006208, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1630055286.288277)
    updated_at = Time.at(1630055329.5910301)
    started_at = Time.at(1630055310.17231)
    ended_at = Time.at(1630055329.590471)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006208] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006208] = id
  end
end
created_at = Time.at(1630055352.870037)
updated_at = Time.at(1630055377.391571)
ended_at = Time.at(1630055377.391114)
obj_was = Game.where("id"=>50006209, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1630055352.870037)
    updated_at = Time.at(1630055377.391571)
    ended_at = Time.at(1630055377.391114)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006209] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006209] = id
  end
end
created_at = Time.at(1630055429.9368162)
updated_at = Time.at(1630055447.41872)
ended_at = Time.at(1630055447.418337)
obj_was = Game.where("id"=>50006210, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1630055429.9368162)
    updated_at = Time.at(1630055447.41872)
    ended_at = Time.at(1630055447.418337)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006210] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006210] = id
  end
end
created_at = Time.at(1630055454.5417411)
updated_at = Time.at(1630063860.6145952)
ended_at = Time.at(1630063860.614037)
obj_was = Game.where("id"=>50006211, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1630055454.5417411)
    updated_at = Time.at(1630063860.6145952)
    ended_at = Time.at(1630063860.614037)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006211] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006211] = id
  end
end
created_at = Time.at(1630236536.7985091)
updated_at = Time.at(1630248181.24989)
started_at = Time.at(1630236552.426622)
ended_at = Time.at(1630248181.249523)
obj_was = Game.where("id"=>50006219, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1630236536.7985091)
    updated_at = Time.at(1630248181.24989)
    started_at = Time.at(1630236552.426622)
    ended_at = Time.at(1630248181.249523)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006219] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006219] = id
  end
end
created_at = Time.at(1630248198.354947)
updated_at = Time.at(1630248732.8443332)
ended_at = Time.at(1630248732.843992)
obj_was = Game.where("id"=>50006220, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1630248198.354947)
    updated_at = Time.at(1630248732.8443332)
    ended_at = Time.at(1630248732.843992)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006220] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006220] = id
  end
end
created_at = Time.at(1630490958.0080562)
updated_at = Time.at(1630490958.0080562)
obj_was = Game.where("id"=>50006227, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1630490958.0080562)
    updated_at = Time.at(1630490958.0080562)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006227] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006227] = id
  end
end
created_at = Time.at(1630491587.343592)
updated_at = Time.at(1630491654.501555)
started_at = Time.at(1630491620.9295812)
ended_at = Time.at(1630491654.5004318)
obj_was = Game.where("id"=>50006229, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1630491587.343592)
    updated_at = Time.at(1630491654.501555)
    started_at = Time.at(1630491620.9295812)
    ended_at = Time.at(1630491654.5004318)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006229] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006229] = id
  end
end
created_at = Time.at(1630491813.62533)
updated_at = Time.at(1630491813.62533)
obj_was = Game.where("id"=>50006230, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1630491813.62533)
    updated_at = Time.at(1630491813.62533)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006230] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006230] = id
  end
end
created_at = Time.at(1630492795.4208808)
updated_at = Time.at(1630492795.4208808)
obj_was = Game.where("id"=>50006231, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1630492795.4208808)
    updated_at = Time.at(1630492795.4208808)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006231] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006231] = id
  end
end
created_at = Time.at(1630493222.549092)
updated_at = Time.at(1630493222.549092)
obj_was = Game.where("id"=>50006232, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1630493222.549092)
    updated_at = Time.at(1630493222.549092)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006232] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006232] = id
  end
end
created_at = Time.at(1630493340.318667)
updated_at = Time.at(1630493390.315064)
obj_was = Game.where("id"=>50006233, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    data = {"tmp_results"=>{"playera"=>{"result"=>0, "innings"=>0, "innings_list"=>[], "innings_redo_list"=>[], "hs"=>0, "gd"=>0.0, "balls_goal"=>nil, "tc"=>0}, "playerb"=>{"result"=>0, "innings"=>0, "innings_list"=>[], "innings_redo_list"=>[], "hs"=>0, "gd"=>0.0, "balls_goal"=>nil, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "state"=>"game_setup_started"}}
    obj.data = data
    created_at = Time.at(1630493340.318667)
    updated_at = Time.at(1630493390.315064)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006233] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006233] = id
  end
end
created_at = Time.at(1630493784.066962)
updated_at = Time.at(1630493784.066962)
obj_was = Game.where("id"=>50006234, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1630493784.066962)
    updated_at = Time.at(1630493784.066962)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006234] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006234] = id
  end
end
created_at = Time.at(1630691412.148326)
updated_at = Time.at(1630691412.148326)
obj_was = Game.where("id"=>50006335, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1630691412.148326)
    updated_at = Time.at(1630691412.148326)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006335] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006335] = id
  end
end
created_at = Time.at(1630695246.9455612)
updated_at = Time.at(1630695411.941762)
started_at = Time.at(1630695411.9413362)
obj_was = Game.where("id"=>50006338, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, started_at: started_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1630695246.9455612)
    updated_at = Time.at(1630695411.941762)
    started_at = Time.at(1630695411.9413362)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006338] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006338] = id
  end
end
created_at = Time.at(1630705261.508846)
updated_at = Time.at(1630705774.720802)
started_at = Time.at(1630705270.80547)
ended_at = Time.at(1630705774.720205)
obj_was = Game.where("id"=>50006342, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1630705261.508846)
    updated_at = Time.at(1630705774.720802)
    started_at = Time.at(1630705270.80547)
    ended_at = Time.at(1630705774.720205)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006342] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006342] = id
  end
end
created_at = Time.at(1630987456.584705)
updated_at = Time.at(1630987660.868619)
started_at = Time.at(1630987475.111464)
ended_at = Time.at(1630987660.868118)
obj_was = Game.where("id"=>50006358, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1630987456.584705)
    updated_at = Time.at(1630987660.868619)
    started_at = Time.at(1630987475.111464)
    ended_at = Time.at(1630987660.868118)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006358] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006358] = id
  end
end
created_at = Time.at(1631195983.1144772)
updated_at = Time.at(1631195983.1144772)
obj_was = Game.where("id"=>50006374, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1631195983.1144772)
    updated_at = Time.at(1631195983.1144772)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006374] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006374] = id
  end
end
created_at = Time.at(1631201158.945038)
updated_at = Time.at(1631204411.2823539)
started_at = Time.at(1631201303.442754)
ended_at = Time.at(1631204411.2813492)
obj_was = Game.where("id"=>50006405, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1631201158.945038)
    updated_at = Time.at(1631204411.2823539)
    started_at = Time.at(1631201303.442754)
    ended_at = Time.at(1631204411.2813492)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006405] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006405] = id
  end
end
created_at = Time.at(1631205657.2319942)
updated_at = Time.at(1631210710.910086)
started_at = Time.at(1631205961.6351209)
ended_at = Time.at(1631210710.909015)
obj_was = Game.where("id"=>50006411, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1631205657.2319942)
    updated_at = Time.at(1631210710.910086)
    started_at = Time.at(1631205961.6351209)
    ended_at = Time.at(1631210710.909015)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006411] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006411] = id
  end
end
created_at = Time.at(1631214504.281868)
updated_at = Time.at(1631216359.030226)
started_at = Time.at(1631214532.783208)
ended_at = Time.at(1631216359.028994)
obj_was = Game.where("id"=>50006418, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1631214504.281868)
    updated_at = Time.at(1631216359.030226)
    started_at = Time.at(1631214532.783208)
    ended_at = Time.at(1631216359.028994)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006418] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006418] = id
  end
end
created_at = Time.at(1631216505.095996)
updated_at = Time.at(1631218720.049506)
started_at = Time.at(1631216525.695562)
ended_at = Time.at(1631218720.048474)
obj_was = Game.where("id"=>50006420, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1631216505.095996)
    updated_at = Time.at(1631218720.049506)
    started_at = Time.at(1631216525.695562)
    ended_at = Time.at(1631218720.048474)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006420] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006420] = id
  end
end
created_at = Time.at(1631218730.236407)
updated_at = Time.at(1631220840.438818)
ended_at = Time.at(1631220840.437748)
obj_was = Game.where("id"=>50006421, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1631218730.236407)
    updated_at = Time.at(1631220840.438818)
    ended_at = Time.at(1631220840.437748)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006421] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006421] = id
  end
end
created_at = Time.at(1631218959.646639)
updated_at = Time.at(1631218959.646639)
obj_was = Game.where("id"=>50006422, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1631218959.646639)
    updated_at = Time.at(1631218959.646639)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006422] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006422] = id
  end
end
created_at = Time.at(1631220856.629774)
updated_at = Time.at(1631222921.616847)
ended_at = Time.at(1631222921.615767)
obj_was = Game.where("id"=>50006423, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1631220856.629774)
    updated_at = Time.at(1631222921.616847)
    ended_at = Time.at(1631222921.615767)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006423] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006423] = id
  end
end
created_at = Time.at(1631287775.6899872)
updated_at = Time.at(1631292770.3541372)
started_at = Time.at(1631287794.636)
ended_at = Time.at(1631292770.3530738)
obj_was = Game.where("id"=>50006425, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1631287775.6899872)
    updated_at = Time.at(1631292770.3541372)
    started_at = Time.at(1631287794.636)
    ended_at = Time.at(1631292770.3530738)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006425] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006425] = id
  end
end
created_at = Time.at(1631293644.231165)
updated_at = Time.at(1631377394.385016)
started_at = Time.at(1631372711.936876)
ended_at = Time.at(1631377394.383899)
obj_was = Game.where("id"=>50006426, "tournament_id"=>11911, "seqno"=>13, "gname"=>"group1:1-2", "group_no"=>1, "table_no"=>1, "round_no"=>5, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>11911, "seqno"=>13, "gname"=>"group1:1-2", "group_no"=>1, "table_no"=>1, "round_no"=>5).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>11911, "seqno"=>13, "gname"=>"group1:1-2", "group_no"=>1, "table_no"=>1, "round_no"=>5)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    created_at = Time.at(1631293644.231165)
    updated_at = Time.at(1631377394.385016)
    started_at = Time.at(1631372711.936876)
    ended_at = Time.at(1631377394.383899)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006426] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006426] = id
  end
end
created_at = Time.at(1631293644.3168588)
updated_at = Time.at(1631372320.5149288)
started_at = Time.at(1631368044.95947)
ended_at = Time.at(1631372246.440643)
obj_was = Game.where("id"=>50006427, "tournament_id"=>11911, "seqno"=>12, "gname"=>"group1:1-3", "group_no"=>1, "table_no"=>3, "round_no"=>4, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>11911, "seqno"=>12, "gname"=>"group1:1-3", "group_no"=>1, "table_no"=>3, "round_no"=>4).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>11911, "seqno"=>12, "gname"=>"group1:1-3", "group_no"=>1, "table_no"=>3, "round_no"=>4)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>12, "Spieler1"=>352853, "Spieler2"=>247211, "Ergebnis1"=>60, "Ergebnis2"=>80, "Aufnahmen1"=>17, "Aufnahmen2"=>17, "Höchstserie1"=>23, "Höchstserie2"=>27, "Tischnummer"=>3}, "tmp_results"=>{"playera"=>{"result"=>60, "innings"=>17, "innings_list"=>[6, 1, 23, 0, 7, 1, 3, 0, 1, 0, 1, 1, 1, 5, 0, 3, 7], "innings_redo_list"=>[0], "hs"=>23, "gd"=>"3.53", "balls_goal"=>80, "tc"=>0}, "playerb"=>{"result"=>80, "innings"=>17, "innings_list"=>[11, 6, 27, 1, 1, 3, 2, 3, 0, 4, 1, 0, 0, 1, 12, 2, 6], "innings_redo_list"=>[], "hs"=>27, "gd"=>"4.71", "balls_goal"=>80, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>1, "Partie"=>12, "Spieler1"=>352853, "Spieler2"=>247211, "Ergebnis1"=>60, "Ergebnis2"=>80, "Aufnahmen1"=>17, "Aufnahmen2"=>17, "Höchstserie1"=>23, "Höchstserie2"=>27, "Tischnummer"=>3}, "state"=>"ready_for_new_game"}}
    obj.data = data
    created_at = Time.at(1631293644.3168588)
    updated_at = Time.at(1631372320.5149288)
    started_at = Time.at(1631368044.95947)
    ended_at = Time.at(1631372246.440643)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006427] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006427] = id
  end
end
created_at = Time.at(1631293644.3529549)
updated_at = Time.at(1631365361.465258)
started_at = Time.at(1631360980.789769)
ended_at = Time.at(1631365195.323634)
obj_was = Game.where("id"=>50006428, "tournament_id"=>11911, "seqno"=>7, "gname"=>"group1:1-4", "group_no"=>1, "table_no"=>1, "round_no"=>3, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>11911, "seqno"=>7, "gname"=>"group1:1-4", "group_no"=>1, "table_no"=>1, "round_no"=>3).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>11911, "seqno"=>7, "gname"=>"group1:1-4", "group_no"=>1, "table_no"=>1, "round_no"=>3)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>7, "Spieler1"=>352853, "Spieler2"=>121340, "Ergebnis1"=>80, "Ergebnis2"=>57, "Aufnahmen1"=>17, "Aufnahmen2"=>17, "Höchstserie1"=>26, "Höchstserie2"=>17, "Tischnummer"=>1}, "tmp_results"=>{"playera"=>{"result"=>80, "innings"=>17, "innings_list"=>[0, 0, 12, 3, 2, 0, 2, 26, 0, 2, 0, 0, 0, 3, 2, 19, 9], "innings_redo_list"=>[0], "hs"=>26, "gd"=>"4.71", "balls_goal"=>80, "tc"=>0}, "playerb"=>{"result"=>57, "innings"=>17, "innings_list"=>[0, 4, 0, 8, 0, 1, 0, 17, 1, 1, 1, 0, 7, 5, 8, 4, 0], "innings_redo_list"=>[], "hs"=>17, "gd"=>"3.35", "balls_goal"=>80, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>1, "Partie"=>7, "Spieler1"=>352853, "Spieler2"=>121340, "Ergebnis1"=>80, "Ergebnis2"=>57, "Aufnahmen1"=>17, "Aufnahmen2"=>17, "Höchstserie1"=>26, "Höchstserie2"=>17, "Tischnummer"=>1}, "state"=>"ready_for_new_game"}}
    obj.data = data
    created_at = Time.at(1631293644.3529549)
    updated_at = Time.at(1631365361.465258)
    started_at = Time.at(1631360980.789769)
    ended_at = Time.at(1631365195.323634)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006428] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006428] = id
  end
end
created_at = Time.at(1631293644.388371)
updated_at = Time.at(1631360350.403039)
started_at = Time.at(1631355950.984859)
ended_at = Time.at(1631360061.92329)
obj_was = Game.where("id"=>50006429, "tournament_id"=>11911, "seqno"=>5, "gname"=>"group1:1-5", "group_no"=>1, "table_no"=>2, "round_no"=>2, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>11911, "seqno"=>5, "gname"=>"group1:1-5", "group_no"=>1, "table_no"=>2, "round_no"=>2).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>11911, "seqno"=>5, "gname"=>"group1:1-5", "group_no"=>1, "table_no"=>2, "round_no"=>2)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>5, "Spieler1"=>352853, "Spieler2"=>228105, "Ergebnis1"=>71, "Ergebnis2"=>41, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>14, "Höchstserie2"=>12, "Tischnummer"=>2}, "tmp_results"=>{"playera"=>{"result"=>71, "innings"=>20, "innings_list"=>[5, 6, 0, 1, 9, 1, 0, 2, 14, 7, 0, 1, 1, 0, 0, 0, 12, 5, 5, 2], "innings_redo_list"=>[0], "hs"=>14, "gd"=>"3.55", "balls_goal"=>80, "tc"=>0}, "playerb"=>{"result"=>41, "innings"=>20, "innings_list"=>[6, 3, 1, 0, 2, 1, 0, 2, 0, 0, 1, 0, 12, 6, 3, 1, 0, 2, 1, 0], "innings_redo_list"=>[], "hs"=>12, "gd"=>"2.05", "balls_goal"=>80, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>1, "Partie"=>5, "Spieler1"=>352853, "Spieler2"=>228105, "Ergebnis1"=>71, "Ergebnis2"=>41, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>14, "Höchstserie2"=>12, "Tischnummer"=>2}, "state"=>"ready_for_new_game"}}
    obj.data = data
    created_at = Time.at(1631293644.388371)
    updated_at = Time.at(1631360350.403039)
    started_at = Time.at(1631355950.984859)
    ended_at = Time.at(1631360061.92329)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006429] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006429] = id
  end
end
created_at = Time.at(1631293644.423899)
updated_at = Time.at(1631355650.806769)
started_at = Time.at(1631350236.1634848)
ended_at = Time.at(1631355620.7418182)
obj_was = Game.where("id"=>50006430, "tournament_id"=>11911, "seqno"=>3, "gname"=>"group1:1-6", "group_no"=>1, "table_no"=>3, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>11911, "seqno"=>3, "gname"=>"group1:1-6", "group_no"=>1, "table_no"=>3, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>11911, "seqno"=>3, "gname"=>"group1:1-6", "group_no"=>1, "table_no"=>3, "round_no"=>1)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>3, "Spieler1"=>352853, "Spieler2"=>352025, "Ergebnis1"=>66, "Ergebnis2"=>69, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>25, "Höchstserie2"=>17, "Tischnummer"=>3}, "tmp_results"=>{"playera"=>{"result"=>66, "innings"=>20, "innings_list"=>[25, 1, 0, 0, 0, 0, 1, 9, 0, 2, 6, 1, 2, 7, 2, 3, 2, 0, 2, 3], "innings_redo_list"=>[0], "hs"=>25, "gd"=>"3.30", "balls_goal"=>80, "tc"=>0}, "playerb"=>{"result"=>69, "innings"=>20, "innings_list"=>[1, 0, 0, 0, 1, 1, 1, 7, 4, 12, 1, 5, 3, 17, 0, 0, 0, 0, 0, 16], "innings_redo_list"=>[], "hs"=>17, "gd"=>"3.45", "balls_goal"=>80, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>1, "Partie"=>3, "Spieler1"=>352853, "Spieler2"=>352025, "Ergebnis1"=>66, "Ergebnis2"=>69, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>25, "Höchstserie2"=>17, "Tischnummer"=>3}, "state"=>"ready_for_new_game"}}
    obj.data = data
    created_at = Time.at(1631293644.423899)
    updated_at = Time.at(1631355650.806769)
    started_at = Time.at(1631350236.1634848)
    ended_at = Time.at(1631355620.7418182)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006430] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006430] = id
  end
end
created_at = Time.at(1631293644.459539)
updated_at = Time.at(1631365361.747402)
started_at = Time.at(1631361118.663579)
ended_at = Time.at(1631365276.87999)
obj_was = Game.where("id"=>50006431, "tournament_id"=>11911, "seqno"=>8, "gname"=>"group1:2-3", "group_no"=>1, "table_no"=>2, "round_no"=>3, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>11911, "seqno"=>8, "gname"=>"group1:2-3", "group_no"=>1, "table_no"=>2, "round_no"=>3).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>11911, "seqno"=>8, "gname"=>"group1:2-3", "group_no"=>1, "table_no"=>2, "round_no"=>3)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>8, "Spieler1"=>156194, "Spieler2"=>247211, "Ergebnis1"=>43, "Ergebnis2"=>77, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>9, "Höchstserie2"=>14, "Tischnummer"=>2}, "tmp_results"=>{"playera"=>{"result"=>43, "innings"=>20, "innings_list"=>[5, 2, 1, 0, 3, 0, 0, 7, 1, 2, 1, 9, 7, 0, 1, 0, 2, 0, 2, 0], "innings_redo_list"=>[0], "hs"=>9, "gd"=>"2.15", "balls_goal"=>80, "tc"=>0}, "playerb"=>{"result"=>77, "innings"=>20, "innings_list"=>[2, 5, 2, 6, 5, 0, 0, 3, 14, 0, 3, 3, 3, 9, 6, 0, 2, 0, 14, 0], "innings_redo_list"=>[], "hs"=>14, "gd"=>"3.85", "balls_goal"=>80, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>1, "Partie"=>8, "Spieler1"=>156194, "Spieler2"=>247211, "Ergebnis1"=>43, "Ergebnis2"=>77, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>9, "Höchstserie2"=>14, "Tischnummer"=>2}, "state"=>"ready_for_new_game"}}
    obj.data = data
    created_at = Time.at(1631293644.459539)
    updated_at = Time.at(1631365361.747402)
    started_at = Time.at(1631361118.663579)
    ended_at = Time.at(1631365276.87999)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006431] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006431] = id
  end
end
created_at = Time.at(1631293644.495882)
updated_at = Time.at(1631360350.676779)
started_at = Time.at(1631356379.978784)
ended_at = Time.at(1631360266.838169)
obj_was = Game.where("id"=>50006432, "tournament_id"=>11911, "seqno"=>6, "gname"=>"group1:2-4", "group_no"=>1, "table_no"=>3, "round_no"=>2, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>11911, "seqno"=>6, "gname"=>"group1:2-4", "group_no"=>1, "table_no"=>3, "round_no"=>2).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>11911, "seqno"=>6, "gname"=>"group1:2-4", "group_no"=>1, "table_no"=>3, "round_no"=>2)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>6, "Spieler1"=>121340, "Spieler2"=>156194, "Ergebnis1"=>52, "Ergebnis2"=>54, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>8, "Höchstserie2"=>13, "Tischnummer"=>3}, "tmp_results"=>{"playera"=>{"result"=>52, "innings"=>20, "innings_list"=>[3, 8, 2, 1, 2, 1, 6, 2, 0, 4, 2, 5, 0, 3, 2, 1, 0, 0, 4, 6], "innings_redo_list"=>[0], "hs"=>8, "gd"=>"2.60", "balls_goal"=>80, "tc"=>0}, "playerb"=>{"result"=>54, "innings"=>20, "innings_list"=>[0, 8, 13, 4, 0, 0, 4, 4, 4, 0, 0, 2, 6, 3, 3, 1, 1, 0, 0, 1], "innings_redo_list"=>[], "hs"=>13, "gd"=>"2.70", "balls_goal"=>80, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>1, "Partie"=>6, "Spieler1"=>121340, "Spieler2"=>156194, "Ergebnis1"=>52, "Ergebnis2"=>54, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>8, "Höchstserie2"=>13, "Tischnummer"=>3}, "state"=>"ready_for_new_game"}}
    obj.data = data
    created_at = Time.at(1631293644.495882)
    updated_at = Time.at(1631360350.676779)
    started_at = Time.at(1631356379.978784)
    ended_at = Time.at(1631360266.838169)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006432] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006432] = id
  end
end
created_at = Time.at(1631293644.531896)
updated_at = Time.at(1631355650.254959)
started_at = Time.at(1631350107.2303889)
ended_at = Time.at(1631353386.3727171)
obj_was = Game.where("id"=>50006433, "tournament_id"=>11911, "seqno"=>1, "gname"=>"group1:2-5", "group_no"=>1, "table_no"=>1, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>11911, "seqno"=>1, "gname"=>"group1:2-5", "group_no"=>1, "table_no"=>1, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>11911, "seqno"=>1, "gname"=>"group1:2-5", "group_no"=>1, "table_no"=>1, "round_no"=>1)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>1, "Spieler1"=>156194, "Spieler2"=>228105, "Ergebnis1"=>49, "Ergebnis2"=>44, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>16, "Höchstserie2"=>9, "Tischnummer"=>1}, "tmp_results"=>{"playera"=>{"result"=>49, "innings"=>20, "innings_list"=>[0, 2, 16, 0, 3, 0, 2, 7, 0, 1, 0, 10, 0, 0, 3, 1, 0, 0, 4, 0], "innings_redo_list"=>[0], "hs"=>16, "gd"=>"2.45", "balls_goal"=>80, "tc"=>0}, "playerb"=>{"result"=>44, "innings"=>20, "innings_list"=>[0, 5, 9, 8, 0, 0, 5, 0, 0, 1, 3, 0, 2, 0, 0, 2, 2, 0, 5, 2], "innings_redo_list"=>[], "hs"=>9, "gd"=>"2.20", "balls_goal"=>80, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>1, "Partie"=>1, "Spieler1"=>156194, "Spieler2"=>228105, "Ergebnis1"=>49, "Ergebnis2"=>44, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>16, "Höchstserie2"=>9, "Tischnummer"=>1}, "state"=>"ready_for_new_game"}}
    obj.data = data
    created_at = Time.at(1631293644.531896)
    updated_at = Time.at(1631355650.254959)
    started_at = Time.at(1631350107.2303889)
    ended_at = Time.at(1631353386.3727171)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006433] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006433] = id
  end
end
created_at = Time.at(1631293644.568096)
updated_at = Time.at(1631372320.240345)
started_at = Time.at(1631367449.3869529)
ended_at = Time.at(1631371839.117951)
obj_was = Game.where("id"=>50006434, "tournament_id"=>11911, "seqno"=>11, "gname"=>"group1:2-6", "group_no"=>1, "table_no"=>2, "round_no"=>4, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>11911, "seqno"=>11, "gname"=>"group1:2-6", "group_no"=>1, "table_no"=>2, "round_no"=>4).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>11911, "seqno"=>11, "gname"=>"group1:2-6", "group_no"=>1, "table_no"=>2, "round_no"=>4)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>11, "Spieler1"=>352025, "Spieler2"=>156194, "Ergebnis1"=>68, "Ergebnis2"=>78, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>11, "Höchstserie2"=>16, "Tischnummer"=>2}, "tmp_results"=>{"playera"=>{"result"=>68, "innings"=>20, "innings_list"=>[0, 8, 1, 2, 2, 1, 0, 9, 1, 8, 2, 4, 5, 0, 4, 0, 11, 0, 3, 7], "innings_redo_list"=>[0], "hs"=>11, "gd"=>"3.40", "balls_goal"=>80, "tc"=>0}, "playerb"=>{"result"=>78, "innings"=>20, "innings_list"=>[1, 2, 5, 7, 1, 0, 0, 2, 10, 3, 0, 9, 12, 4, 0, 2, 16, 4, 0, 0], "innings_redo_list"=>[], "hs"=>16, "gd"=>"3.90", "balls_goal"=>80, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>1, "Partie"=>11, "Spieler1"=>352025, "Spieler2"=>156194, "Ergebnis1"=>68, "Ergebnis2"=>78, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>11, "Höchstserie2"=>16, "Tischnummer"=>2}, "state"=>"ready_for_new_game"}}
    obj.data = data
    created_at = Time.at(1631293644.568096)
    updated_at = Time.at(1631372320.240345)
    started_at = Time.at(1631367449.3869529)
    ended_at = Time.at(1631371839.117951)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006434] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006434] = id
  end
end
created_at = Time.at(1631293644.604372)
updated_at = Time.at(1631355650.5275679)
started_at = Time.at(1631350469.818505)
ended_at = Time.at(1631354420.497911)
obj_was = Game.where("id"=>50006435, "tournament_id"=>11911, "seqno"=>2, "gname"=>"group1:3-4", "group_no"=>1, "table_no"=>2, "round_no"=>1, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>11911, "seqno"=>2, "gname"=>"group1:3-4", "group_no"=>1, "table_no"=>2, "round_no"=>1).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>11911, "seqno"=>2, "gname"=>"group1:3-4", "group_no"=>1, "table_no"=>2, "round_no"=>1)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>2, "Spieler1"=>121340, "Spieler2"=>247211, "Ergebnis1"=>24, "Ergebnis2"=>69, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>7, "Höchstserie2"=>11, "Tischnummer"=>2}, "tmp_results"=>{"playera"=>{"result"=>24, "innings"=>20, "innings_list"=>[0, 0, 7, 3, 1, 0, 0, 0, 0, 1, 0, 1, 2, 0, 1, 0, 2, 2, 2, 2], "innings_redo_list"=>[0], "hs"=>7, "gd"=>"1.20", "balls_goal"=>80, "tc"=>0, "discipline"=>"Freie Partie klein"}, "playerb"=>{"result"=>69, "innings"=>20, "innings_list"=>[5, 3, 6, 0, 4, 9, 1, 0, 2, 1, 0, 5, 3, 2, 7, 2, 1, 2, 5, 11], "innings_redo_list"=>[], "hs"=>11, "gd"=>"3.45", "balls_goal"=>80, "tc"=>0, "discipline"=>"Freie Partie klein"}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>1, "Partie"=>2, "Spieler1"=>121340, "Spieler2"=>247211, "Ergebnis1"=>24, "Ergebnis2"=>69, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>7, "Höchstserie2"=>11, "Tischnummer"=>2}, "state"=>"ready_for_new_game"}}
    obj.data = data
    created_at = Time.at(1631293644.604372)
    updated_at = Time.at(1631355650.5275679)
    started_at = Time.at(1631350469.818505)
    ended_at = Time.at(1631354420.497911)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006435] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006435] = id
  end
end
created_at = Time.at(1631293644.640584)
updated_at = Time.at(1631376204.341289)
started_at = Time.at(1631372550.212319)
ended_at = Time.at(1631375499.436907)
obj_was = Game.where("id"=>50006436, "tournament_id"=>11911, "seqno"=>15, "gname"=>"group1:3-5", "group_no"=>1, "table_no"=>3, "round_no"=>5, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>11911, "seqno"=>15, "gname"=>"group1:3-5", "group_no"=>1, "table_no"=>3, "round_no"=>5).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>11911, "seqno"=>15, "gname"=>"group1:3-5", "group_no"=>1, "table_no"=>3, "round_no"=>5)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>15, "Spieler1"=>247211, "Spieler2"=>228105, "Ergebnis1"=>67, "Ergebnis2"=>23, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>16, "Höchstserie2"=>3, "Tischnummer"=>3}}
    obj.data = data
    created_at = Time.at(1631293644.640584)
    updated_at = Time.at(1631376204.341289)
    started_at = Time.at(1631372550.212319)
    ended_at = Time.at(1631375499.436907)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006436] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006436] = id
  end
end
created_at = Time.at(1631293644.700746)
updated_at = Time.at(1631360350.131681)
started_at = Time.at(1631355911.1048472)
ended_at = Time.at(1631359371.982757)
obj_was = Game.where("id"=>50006437, "tournament_id"=>11911, "seqno"=>4, "gname"=>"group1:3-6", "group_no"=>1, "table_no"=>1, "round_no"=>2, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>11911, "seqno"=>4, "gname"=>"group1:3-6", "group_no"=>1, "table_no"=>1, "round_no"=>2).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>11911, "seqno"=>4, "gname"=>"group1:3-6", "group_no"=>1, "table_no"=>1, "round_no"=>2)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>4, "Spieler1"=>352025, "Spieler2"=>247211, "Ergebnis1"=>41, "Ergebnis2"=>45, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>14, "Höchstserie2"=>11, "Tischnummer"=>1}, "tmp_results"=>{"playera"=>{"result"=>41, "innings"=>20, "innings_list"=>[6, 1, 1, 2, 2, 2, 1, 0, 3, 1, 0, 0, 3, 0, 2, 0, 14, 0, 3, 0], "innings_redo_list"=>[0], "hs"=>14, "gd"=>"2.05", "balls_goal"=>80, "tc"=>0}, "playerb"=>{"result"=>45, "innings"=>20, "innings_list"=>[0, 1, 1, 2, 5, 1, 1, 0, 5, 2, 0, 7, 2, 11, 0, 0, 4, 1, 2, 0], "innings_redo_list"=>[], "hs"=>11, "gd"=>"2.25", "balls_goal"=>80, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>1, "Partie"=>4, "Spieler1"=>352025, "Spieler2"=>247211, "Ergebnis1"=>41, "Ergebnis2"=>45, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>14, "Höchstserie2"=>11, "Tischnummer"=>1}, "state"=>"ready_for_new_game"}}
    obj.data = data
    created_at = Time.at(1631293644.700746)
    updated_at = Time.at(1631360350.131681)
    started_at = Time.at(1631355911.1048472)
    ended_at = Time.at(1631359371.982757)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006437] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006437] = id
  end
end
created_at = Time.at(1631293644.737288)
updated_at = Time.at(1631372319.9660008)
started_at = Time.at(1631367273.922007)
ended_at = Time.at(1631370877.5250502)
obj_was = Game.where("id"=>50006438, "tournament_id"=>11911, "seqno"=>10, "gname"=>"group1:4-5", "group_no"=>1, "table_no"=>1, "round_no"=>4, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>11911, "seqno"=>10, "gname"=>"group1:4-5", "group_no"=>1, "table_no"=>1, "round_no"=>4).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>11911, "seqno"=>10, "gname"=>"group1:4-5", "group_no"=>1, "table_no"=>1, "round_no"=>4)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>10, "Spieler1"=>121340, "Spieler2"=>228105, "Ergebnis1"=>69, "Ergebnis2"=>51, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>20, "Höchstserie2"=>14, "Tischnummer"=>1}, "tmp_results"=>{"playera"=>{"result"=>69, "innings"=>20, "innings_list"=>[0, 20, 2, 3, 2, 2, 12, 10, 9, 1, 0, 0, 1, 0, 0, 3, 3, 0, 1, 0], "innings_redo_list"=>[0], "hs"=>20, "gd"=>"3.45", "balls_goal"=>80, "tc"=>0}, "playerb"=>{"result"=>51, "innings"=>20, "innings_list"=>[1, 4, 2, 0, 4, 3, 14, 1, 1, 0, 0, 0, 12, 2, 0, 4, 3, 0, 0, 0], "innings_redo_list"=>[], "hs"=>14, "gd"=>"2.55", "balls_goal"=>80, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>1, "Partie"=>10, "Spieler1"=>121340, "Spieler2"=>228105, "Ergebnis1"=>69, "Ergebnis2"=>51, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>20, "Höchstserie2"=>14, "Tischnummer"=>1}, "state"=>"ready_for_new_game"}}
    obj.data = data
    created_at = Time.at(1631293644.737288)
    updated_at = Time.at(1631372319.9660008)
    started_at = Time.at(1631367273.922007)
    ended_at = Time.at(1631370877.5250502)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006438] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006438] = id
  end
end
created_at = Time.at(1631293644.7728589)
updated_at = Time.at(1631377410.516068)
started_at = Time.at(1631372463.4621198)
ended_at = Time.at(1631376950.660083)
obj_was = Game.where("id"=>50006439, "tournament_id"=>11911, "seqno"=>14, "gname"=>"group1:4-6", "group_no"=>1, "table_no"=>2, "round_no"=>5, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>11911, "seqno"=>14, "gname"=>"group1:4-6", "group_no"=>1, "table_no"=>2, "round_no"=>5).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>11911, "seqno"=>14, "gname"=>"group1:4-6", "group_no"=>1, "table_no"=>2, "round_no"=>5)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>14, "Spieler1"=>352025, "Spieler2"=>121340, "Ergebnis1"=>75, "Ergebnis2"=>65, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>16, "Höchstserie2"=>15, "Tischnummer"=>2}}
    obj.data = data
    created_at = Time.at(1631293644.7728589)
    updated_at = Time.at(1631377410.516068)
    started_at = Time.at(1631372463.4621198)
    ended_at = Time.at(1631376950.660083)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006439] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006439] = id
  end
end
created_at = Time.at(1631293644.808049)
updated_at = Time.at(1631365362.025695)
started_at = Time.at(1631360632.9641678)
ended_at = Time.at(1631363768.336608)
obj_was = Game.where("id"=>50006440, "tournament_id"=>11911, "seqno"=>9, "gname"=>"group1:5-6", "group_no"=>1, "table_no"=>3, "round_no"=>3, created_at: created_at, updated_at: updated_at, started_at: started_at, ended_at: ended_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>11911, "seqno"=>9, "gname"=>"group1:5-6", "group_no"=>1, "table_no"=>3, "round_no"=>3).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>11911, "seqno"=>9, "gname"=>"group1:5-6", "group_no"=>1, "table_no"=>3, "round_no"=>3)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    data = {"ba_results"=>{"Gruppe"=>1, "Partie"=>9, "Spieler1"=>352025, "Spieler2"=>228105, "Ergebnis1"=>45, "Ergebnis2"=>42, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>13, "Höchstserie2"=>14, "Tischnummer"=>3}, "tmp_results"=>{"playera"=>{"result"=>45, "innings"=>20, "innings_list"=>[2, 5, 2, 3, 0, 0, 0, 1, 0, 0, 0, 7, 3, 0, 2, 3, 3, 1, 0, 13], "innings_redo_list"=>[0], "hs"=>13, "gd"=>"2.25", "balls_goal"=>80, "tc"=>0}, "playerb"=>{"result"=>42, "innings"=>20, "innings_list"=>[0, 14, 1, 1, 0, 0, 0, 2, 1, 1, 1, 0, 2, 0, 2, 0, 1, 3, 4, 9], "innings_redo_list"=>[], "hs"=>14, "gd"=>"2.10", "balls_goal"=>80, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>1, "Partie"=>9, "Spieler1"=>352025, "Spieler2"=>228105, "Ergebnis1"=>45, "Ergebnis2"=>42, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>13, "Höchstserie2"=>14, "Tischnummer"=>3}, "state"=>"ready_for_new_game"}}
    obj.data = data
    created_at = Time.at(1631293644.808049)
    updated_at = Time.at(1631365362.025695)
    started_at = Time.at(1631360632.9641678)
    ended_at = Time.at(1631363768.336608)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006440] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
      obj.update_column(:"ended_at", ended_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006440] = id
  end
end
created_at = Time.at(1631349176.5447009)
updated_at = Time.at(1631349535.9237828)
started_at = Time.at(1631349535.92243)
obj_was = Game.where("id"=>50006444, "tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil, created_at: created_at, updated_at: updated_at, started_at: started_at).first
if obj_was.blank?
  obj_was = Game.where("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil).first
  if obj_was.blank?
    obj = Game.new("tournament_id"=>nil, "seqno"=>nil, "gname"=>nil, "group_no"=>nil, "table_no"=>nil, "round_no"=>nil)
    obj.tournament_id = tournament_id_map[] if tournament_id_map[].present?
    created_at = Time.at(1631349176.5447009)
    updated_at = Time.at(1631349535.9237828)
    started_at = Time.at(1631349535.92243)
    begin
      obj.save!
      id = obj.id
      game_id_map[50006444] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"started_at", started_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_id_map[50006444] = id
  end
end
game_participation_id_map = {}
#+++GameParticipation+++
#---Player---
h1 = JSON.pretty_generate(player_id_map)
#---Game---
h2 = JSON.pretty_generate(game_id_map)
created_at = Time.at(1629042224.577953)
updated_at = Time.at(1629118936.072172)
obj_was = GameParticipation.where("id"=>50011990, "game_id"=>50006123, "player_id"=>261, "role"=>"playera", "points"=>0, "result"=>41, "innings"=>11, "gd"=>3.73, "hs"=>12, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006123, "player_id"=>261, "role"=>"playera", "points"=>0, "result"=>41, "innings"=>11, "gd"=>3.73, "hs"=>12, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006123, "player_id"=>261, "role"=>"playera", "points"=>0, "result"=>41, "innings"=>11, "gd"=>3.73, "hs"=>12, "gname"=>nil)
    obj.game_id = game_id_map[50006123] if game_id_map[50006123].present?
    data = {"results"=>{"Gr."=>"group1:1-2", "Ergebnis"=>41, "Aufnahme"=>11, "GD"=>3.73, "HS"=>12, "gp_id"=>50011990}}
    obj.data = data
    created_at = Time.at(1629042224.577953)
    updated_at = Time.at(1629118936.072172)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50011990] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50011990] = id
  end
end
created_at = Time.at(1629042224.591657)
updated_at = Time.at(1629118936.229322)
obj_was = GameParticipation.where("id"=>50011991, "game_id"=>50006123, "player_id"=>257, "role"=>"playerb", "points"=>2, "result"=>60, "innings"=>11, "gd"=>5.45, "hs"=>13, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006123, "player_id"=>257, "role"=>"playerb", "points"=>2, "result"=>60, "innings"=>11, "gd"=>5.45, "hs"=>13, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006123, "player_id"=>257, "role"=>"playerb", "points"=>2, "result"=>60, "innings"=>11, "gd"=>5.45, "hs"=>13, "gname"=>nil)
    obj.game_id = game_id_map[50006123] if game_id_map[50006123].present?
    data = {"results"=>{"Gr."=>"group1:1-2", "Ergebnis"=>60, "Aufnahme"=>11, "GD"=>5.45, "HS"=>13, "gp_id"=>50011991}}
    obj.data = data
    created_at = Time.at(1629042224.591657)
    updated_at = Time.at(1629118936.229322)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50011991] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50011991] = id
  end
end
created_at = Time.at(1629042224.5986829)
updated_at = Time.at(1630493762.401987)
obj_was = GameParticipation.where("id"=>50011992, "game_id"=>50006124, "player_id"=>261, "role"=>"playera", "points"=>0, "result"=>45, "innings"=>13, "gd"=>3.46, "hs"=>15, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006124, "player_id"=>261, "role"=>"playera", "points"=>0, "result"=>45, "innings"=>13, "gd"=>3.46, "hs"=>15, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006124, "player_id"=>261, "role"=>"playera", "points"=>0, "result"=>45, "innings"=>13, "gd"=>3.46, "hs"=>15, "gname"=>nil)
    obj.game_id = game_id_map[50006124] if game_id_map[50006124].present?
    data = {"results"=>{"Gr."=>"group1:1-3", "Ergebnis"=>45, "Aufnahme"=>13, "GD"=>3.46, "HS"=>15, "gp_id"=>50011992}}
    obj.data = data
    created_at = Time.at(1629042224.5986829)
    updated_at = Time.at(1630493762.401987)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50011992] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50011992] = id
  end
end
created_at = Time.at(1629042224.601988)
updated_at = Time.at(1630493762.520573)
obj_was = GameParticipation.where("id"=>50011993, "game_id"=>50006124, "player_id"=>255, "role"=>"playerb", "points"=>2, "result"=>60, "innings"=>13, "gd"=>4.62, "hs"=>21, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006124, "player_id"=>255, "role"=>"playerb", "points"=>2, "result"=>60, "innings"=>13, "gd"=>4.62, "hs"=>21, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006124, "player_id"=>255, "role"=>"playerb", "points"=>2, "result"=>60, "innings"=>13, "gd"=>4.62, "hs"=>21, "gname"=>nil)
    obj.game_id = game_id_map[50006124] if game_id_map[50006124].present?
    data = {"results"=>{"Gr."=>"group1:1-3", "Ergebnis"=>60, "Aufnahme"=>13, "GD"=>4.62, "HS"=>21, "gp_id"=>50011993}}
    obj.data = data
    created_at = Time.at(1629042224.601988)
    updated_at = Time.at(1630493762.520573)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50011993] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50011993] = id
  end
end
created_at = Time.at(1629042224.608504)
updated_at = Time.at(1629120185.118122)
obj_was = GameParticipation.where("id"=>50011994, "game_id"=>50006125, "player_id"=>261, "role"=>"playera", "points"=>0, "result"=>14, "innings"=>6, "gd"=>2.33, "hs"=>6, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006125, "player_id"=>261, "role"=>"playera", "points"=>0, "result"=>14, "innings"=>6, "gd"=>2.33, "hs"=>6, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006125, "player_id"=>261, "role"=>"playera", "points"=>0, "result"=>14, "innings"=>6, "gd"=>2.33, "hs"=>6, "gname"=>nil)
    obj.game_id = game_id_map[50006125] if game_id_map[50006125].present?
    data = {"results"=>{"Gr."=>"group1:1-4", "Ergebnis"=>14, "Aufnahme"=>6, "GD"=>2.33, "HS"=>6, "gp_id"=>50011994}}
    obj.data = data
    created_at = Time.at(1629042224.608504)
    updated_at = Time.at(1629120185.118122)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50011994] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50011994] = id
  end
end
created_at = Time.at(1629042224.61164)
updated_at = Time.at(1629120185.198514)
obj_was = GameParticipation.where("id"=>50011995, "game_id"=>50006125, "player_id"=>266, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>6, "gd"=>5.33, "hs"=>9, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006125, "player_id"=>266, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>6, "gd"=>5.33, "hs"=>9, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006125, "player_id"=>266, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>6, "gd"=>5.33, "hs"=>9, "gname"=>nil)
    obj.game_id = game_id_map[50006125] if game_id_map[50006125].present?
    data = {"results"=>{"Gr."=>"group1:1-4", "Ergebnis"=>32, "Aufnahme"=>6, "GD"=>5.33, "HS"=>9, "gp_id"=>50011995}}
    obj.data = data
    created_at = Time.at(1629042224.61164)
    updated_at = Time.at(1629120185.198514)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50011995] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50011995] = id
  end
end
created_at = Time.at(1629042224.621984)
updated_at = Time.at(1629121017.3758981)
obj_was = GameParticipation.where("id"=>50011996, "game_id"=>50006126, "player_id"=>261, "role"=>"playera", "points"=>0, "result"=>16, "innings"=>9, "gd"=>1.78, "hs"=>2, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006126, "player_id"=>261, "role"=>"playera", "points"=>0, "result"=>16, "innings"=>9, "gd"=>1.78, "hs"=>2, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006126, "player_id"=>261, "role"=>"playera", "points"=>0, "result"=>16, "innings"=>9, "gd"=>1.78, "hs"=>2, "gname"=>nil)
    obj.game_id = game_id_map[50006126] if game_id_map[50006126].present?
    data = {"results"=>{"Gr."=>"group1:1-5", "Ergebnis"=>16, "Aufnahme"=>9, "GD"=>1.78, "HS"=>2, "gp_id"=>50011996}}
    obj.data = data
    created_at = Time.at(1629042224.621984)
    updated_at = Time.at(1629121017.3758981)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50011996] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50011996] = id
  end
end
created_at = Time.at(1629042224.625133)
updated_at = Time.at(1629121017.4598038)
obj_was = GameParticipation.where("id"=>50011997, "game_id"=>50006126, "player_id"=>254, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>9, "gd"=>1.78, "hs"=>5, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006126, "player_id"=>254, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>9, "gd"=>1.78, "hs"=>5, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006126, "player_id"=>254, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>9, "gd"=>1.78, "hs"=>5, "gname"=>nil)
    obj.game_id = game_id_map[50006126] if game_id_map[50006126].present?
    data = {"results"=>{"Gr."=>"group1:1-5", "Ergebnis"=>16, "Aufnahme"=>9, "GD"=>1.78, "HS"=>5, "gp_id"=>50011997}}
    obj.data = data
    created_at = Time.at(1629042224.625133)
    updated_at = Time.at(1629121017.4598038)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50011997] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50011997] = id
  end
end
created_at = Time.at(1629042224.6360059)
updated_at = Time.at(1629219232.798552)
obj_was = GameParticipation.where("id"=>50011998, "game_id"=>50006127, "player_id"=>261, "role"=>"playera", "points"=>0, "result"=>19, "innings"=>14, "gd"=>1.36, "hs"=>7, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006127, "player_id"=>261, "role"=>"playera", "points"=>0, "result"=>19, "innings"=>14, "gd"=>1.36, "hs"=>7, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006127, "player_id"=>261, "role"=>"playera", "points"=>0, "result"=>19, "innings"=>14, "gd"=>1.36, "hs"=>7, "gname"=>nil)
    obj.game_id = game_id_map[50006127] if game_id_map[50006127].present?
    data = {"results"=>{"Gr."=>"group1:1-6", "Ergebnis"=>19, "Aufnahme"=>14, "GD"=>1.36, "HS"=>7, "gp_id"=>50011998}}
    obj.data = data
    created_at = Time.at(1629042224.6360059)
    updated_at = Time.at(1629219232.798552)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50011998] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50011998] = id
  end
end
created_at = Time.at(1629042224.639661)
updated_at = Time.at(1629219232.9163158)
obj_was = GameParticipation.where("id"=>50011999, "game_id"=>50006127, "player_id"=>247, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>14, "gd"=>1.14, "hs"=>3, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006127, "player_id"=>247, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>14, "gd"=>1.14, "hs"=>3, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006127, "player_id"=>247, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>14, "gd"=>1.14, "hs"=>3, "gname"=>nil)
    obj.game_id = game_id_map[50006127] if game_id_map[50006127].present?
    data = {"results"=>{"Gr."=>"group1:1-6", "Ergebnis"=>16, "Aufnahme"=>14, "GD"=>1.14, "HS"=>3, "gp_id"=>50011999}}
    obj.data = data
    created_at = Time.at(1629042224.639661)
    updated_at = Time.at(1629219232.9163158)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50011999] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50011999] = id
  end
end
created_at = Time.at(1629042224.646857)
updated_at = Time.at(1629042224.646857)
obj_was = GameParticipation.where("id"=>50012000, "game_id"=>50006128, "player_id"=>261, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006128, "player_id"=>261, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006128, "player_id"=>261, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006128] if game_id_map[50006128].present?
    created_at = Time.at(1629042224.646857)
    updated_at = Time.at(1629042224.646857)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012000] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012000] = id
  end
end
created_at = Time.at(1629042224.655818)
updated_at = Time.at(1629042224.655818)
obj_was = GameParticipation.where("id"=>50012001, "game_id"=>50006128, "player_id"=>263, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006128, "player_id"=>263, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006128, "player_id"=>263, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006128] if game_id_map[50006128].present?
    created_at = Time.at(1629042224.655818)
    updated_at = Time.at(1629042224.655818)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012001] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012001] = id
  end
end
created_at = Time.at(1629042224.66902)
updated_at = Time.at(1630140767.083626)
obj_was = GameParticipation.where("id"=>50012002, "game_id"=>50006129, "player_id"=>261, "role"=>"playerb", "points"=>0, "result"=>49, "innings"=>16, "gd"=>3.06, "hs"=>17, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006129, "player_id"=>261, "role"=>"playerb", "points"=>0, "result"=>49, "innings"=>16, "gd"=>3.06, "hs"=>17, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006129, "player_id"=>261, "role"=>"playerb", "points"=>0, "result"=>49, "innings"=>16, "gd"=>3.06, "hs"=>17, "gname"=>nil)
    obj.game_id = game_id_map[50006129] if game_id_map[50006129].present?
    data = {"results"=>{"Gr."=>"group1:1-8", "Ergebnis"=>49, "Aufnahme"=>16, "GD"=>3.06, "HS"=>17, "gp_id"=>50012002}}
    obj.data = data
    created_at = Time.at(1629042224.66902)
    updated_at = Time.at(1630140767.083626)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012002] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012002] = id
  end
end
created_at = Time.at(1629042224.6719842)
updated_at = Time.at(1630140767.0046122)
obj_was = GameParticipation.where("id"=>50012003, "game_id"=>50006129, "player_id"=>249, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>16, "gd"=>1.0, "hs"=>3, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006129, "player_id"=>249, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>16, "gd"=>1.0, "hs"=>3, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006129, "player_id"=>249, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>16, "gd"=>1.0, "hs"=>3, "gname"=>nil)
    obj.game_id = game_id_map[50006129] if game_id_map[50006129].present?
    data = {"results"=>{"Gr."=>"group1:1-8", "Ergebnis"=>16, "Aufnahme"=>16, "GD"=>1.0, "HS"=>3, "gp_id"=>50012003}}
    obj.data = data
    created_at = Time.at(1629042224.6719842)
    updated_at = Time.at(1630140767.0046122)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012003] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012003] = id
  end
end
created_at = Time.at(1629042224.6843631)
updated_at = Time.at(1629220080.128644)
obj_was = GameParticipation.where("id"=>50012004, "game_id"=>50006130, "player_id"=>257, "role"=>"playera", "points"=>2, "result"=>60, "innings"=>4, "gd"=>15.0, "hs"=>36, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006130, "player_id"=>257, "role"=>"playera", "points"=>2, "result"=>60, "innings"=>4, "gd"=>15.0, "hs"=>36, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006130, "player_id"=>257, "role"=>"playera", "points"=>2, "result"=>60, "innings"=>4, "gd"=>15.0, "hs"=>36, "gname"=>nil)
    obj.game_id = game_id_map[50006130] if game_id_map[50006130].present?
    data = {"results"=>{"Gr."=>"group1:2-3", "Ergebnis"=>60, "Aufnahme"=>4, "GD"=>15.0, "HS"=>36, "gp_id"=>50012004}}
    obj.data = data
    created_at = Time.at(1629042224.6843631)
    updated_at = Time.at(1629220080.128644)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012004] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012004] = id
  end
end
created_at = Time.at(1629042224.692091)
updated_at = Time.at(1629220080.271435)
obj_was = GameParticipation.where("id"=>50012005, "game_id"=>50006130, "player_id"=>255, "role"=>"playerb", "points"=>0, "result"=>14, "innings"=>4, "gd"=>3.5, "hs"=>12, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006130, "player_id"=>255, "role"=>"playerb", "points"=>0, "result"=>14, "innings"=>4, "gd"=>3.5, "hs"=>12, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006130, "player_id"=>255, "role"=>"playerb", "points"=>0, "result"=>14, "innings"=>4, "gd"=>3.5, "hs"=>12, "gname"=>nil)
    obj.game_id = game_id_map[50006130] if game_id_map[50006130].present?
    data = {"results"=>{"Gr."=>"group1:2-3", "Ergebnis"=>14, "Aufnahme"=>4, "GD"=>3.5, "HS"=>12, "gp_id"=>50012005}}
    obj.data = data
    created_at = Time.at(1629042224.692091)
    updated_at = Time.at(1629220080.271435)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012005] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012005] = id
  end
end
created_at = Time.at(1629042224.7040331)
updated_at = Time.at(1629120424.573)
obj_was = GameParticipation.where("id"=>50012006, "game_id"=>50006131, "player_id"=>257, "role"=>"playera", "points"=>2, "result"=>60, "innings"=>5, "gd"=>12.0, "hs"=>21, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006131, "player_id"=>257, "role"=>"playera", "points"=>2, "result"=>60, "innings"=>5, "gd"=>12.0, "hs"=>21, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006131, "player_id"=>257, "role"=>"playera", "points"=>2, "result"=>60, "innings"=>5, "gd"=>12.0, "hs"=>21, "gname"=>nil)
    obj.game_id = game_id_map[50006131] if game_id_map[50006131].present?
    data = {"results"=>{"Gr."=>"group1:2-4", "Ergebnis"=>60, "Aufnahme"=>5, "GD"=>12.0, "HS"=>21, "gp_id"=>50012006}}
    obj.data = data
    created_at = Time.at(1629042224.7040331)
    updated_at = Time.at(1629120424.573)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012006] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012006] = id
  end
end
created_at = Time.at(1629042224.7094882)
updated_at = Time.at(1629120424.658613)
obj_was = GameParticipation.where("id"=>50012007, "game_id"=>50006131, "player_id"=>266, "role"=>"playerb", "points"=>0, "result"=>30, "innings"=>5, "gd"=>6.0, "hs"=>13, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006131, "player_id"=>266, "role"=>"playerb", "points"=>0, "result"=>30, "innings"=>5, "gd"=>6.0, "hs"=>13, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006131, "player_id"=>266, "role"=>"playerb", "points"=>0, "result"=>30, "innings"=>5, "gd"=>6.0, "hs"=>13, "gname"=>nil)
    obj.game_id = game_id_map[50006131] if game_id_map[50006131].present?
    data = {"results"=>{"Gr."=>"group1:2-4", "Ergebnis"=>30, "Aufnahme"=>5, "GD"=>6.0, "HS"=>13, "gp_id"=>50012007}}
    obj.data = data
    created_at = Time.at(1629042224.7094882)
    updated_at = Time.at(1629120424.658613)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012007] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012007] = id
  end
end
created_at = Time.at(1629042224.7196531)
updated_at = Time.at(1629123328.014364)
obj_was = GameParticipation.where("id"=>50012008, "game_id"=>50006132, "player_id"=>257, "role"=>"playera", "points"=>0, "result"=>47, "innings"=>12, "gd"=>3.92, "hs"=>32, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006132, "player_id"=>257, "role"=>"playera", "points"=>0, "result"=>47, "innings"=>12, "gd"=>3.92, "hs"=>32, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006132, "player_id"=>257, "role"=>"playera", "points"=>0, "result"=>47, "innings"=>12, "gd"=>3.92, "hs"=>32, "gname"=>nil)
    obj.game_id = game_id_map[50006132] if game_id_map[50006132].present?
    data = {"results"=>{"Gr."=>"group1:2-5", "Ergebnis"=>47, "Aufnahme"=>12, "GD"=>3.92, "HS"=>32, "gp_id"=>50012008}}
    obj.data = data
    created_at = Time.at(1629042224.7196531)
    updated_at = Time.at(1629123328.014364)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012008] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012008] = id
  end
end
created_at = Time.at(1629042224.722741)
updated_at = Time.at(1629123328.16124)
obj_was = GameParticipation.where("id"=>50012009, "game_id"=>50006132, "player_id"=>254, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>12, "gd"=>1.33, "hs"=>4, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006132, "player_id"=>254, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>12, "gd"=>1.33, "hs"=>4, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006132, "player_id"=>254, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>12, "gd"=>1.33, "hs"=>4, "gname"=>nil)
    obj.game_id = game_id_map[50006132] if game_id_map[50006132].present?
    data = {"results"=>{"Gr."=>"group1:2-5", "Ergebnis"=>16, "Aufnahme"=>12, "GD"=>1.33, "HS"=>4, "gp_id"=>50012009}}
    obj.data = data
    created_at = Time.at(1629042224.722741)
    updated_at = Time.at(1629123328.16124)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012009] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012009] = id
  end
end
created_at = Time.at(1629042224.7345731)
updated_at = Time.at(1629042224.7345731)
obj_was = GameParticipation.where("id"=>50012010, "game_id"=>50006133, "player_id"=>257, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006133, "player_id"=>257, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006133, "player_id"=>257, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006133] if game_id_map[50006133].present?
    created_at = Time.at(1629042224.7345731)
    updated_at = Time.at(1629042224.7345731)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012010] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012010] = id
  end
end
created_at = Time.at(1629042224.7406132)
updated_at = Time.at(1629042224.7406132)
obj_was = GameParticipation.where("id"=>50012011, "game_id"=>50006133, "player_id"=>247, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006133, "player_id"=>247, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006133, "player_id"=>247, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006133] if game_id_map[50006133].present?
    created_at = Time.at(1629042224.7406132)
    updated_at = Time.at(1629042224.7406132)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012011] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012011] = id
  end
end
created_at = Time.at(1629042224.750386)
updated_at = Time.at(1629219707.6720698)
obj_was = GameParticipation.where("id"=>50012012, "game_id"=>50006134, "player_id"=>257, "role"=>"playera", "points"=>2, "result"=>60, "innings"=>11, "gd"=>5.45, "hs"=>23, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006134, "player_id"=>257, "role"=>"playera", "points"=>2, "result"=>60, "innings"=>11, "gd"=>5.45, "hs"=>23, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006134, "player_id"=>257, "role"=>"playera", "points"=>2, "result"=>60, "innings"=>11, "gd"=>5.45, "hs"=>23, "gname"=>nil)
    obj.game_id = game_id_map[50006134] if game_id_map[50006134].present?
    data = {"results"=>{"Gr."=>"group1:2-7", "Ergebnis"=>60, "Aufnahme"=>11, "GD"=>5.45, "HS"=>23, "gp_id"=>50012012}}
    obj.data = data
    created_at = Time.at(1629042224.750386)
    updated_at = Time.at(1629219707.6720698)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012012] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012012] = id
  end
end
created_at = Time.at(1629042224.754019)
updated_at = Time.at(1629219707.9092102)
obj_was = GameParticipation.where("id"=>50012013, "game_id"=>50006134, "player_id"=>263, "role"=>"playerb", "points"=>0, "result"=>5, "innings"=>11, "gd"=>0.45, "hs"=>3, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006134, "player_id"=>263, "role"=>"playerb", "points"=>0, "result"=>5, "innings"=>11, "gd"=>0.45, "hs"=>3, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006134, "player_id"=>263, "role"=>"playerb", "points"=>0, "result"=>5, "innings"=>11, "gd"=>0.45, "hs"=>3, "gname"=>nil)
    obj.game_id = game_id_map[50006134] if game_id_map[50006134].present?
    data = {"results"=>{"Gr."=>"group1:2-7", "Ergebnis"=>5, "Aufnahme"=>11, "GD"=>0.45, "HS"=>3, "gp_id"=>50012013}}
    obj.data = data
    created_at = Time.at(1629042224.754019)
    updated_at = Time.at(1629219707.9092102)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012013] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012013] = id
  end
end
created_at = Time.at(1629042224.760675)
updated_at = Time.at(1629119617.668389)
obj_was = GameParticipation.where("id"=>50012014, "game_id"=>50006135, "player_id"=>257, "role"=>"playera", "points"=>0, "result"=>28, "innings"=>17, "gd"=>1.65, "hs"=>10, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006135, "player_id"=>257, "role"=>"playera", "points"=>0, "result"=>28, "innings"=>17, "gd"=>1.65, "hs"=>10, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006135, "player_id"=>257, "role"=>"playera", "points"=>0, "result"=>28, "innings"=>17, "gd"=>1.65, "hs"=>10, "gname"=>nil)
    obj.game_id = game_id_map[50006135] if game_id_map[50006135].present?
    data = {"results"=>{"Gr."=>"group1:2-8", "Ergebnis"=>28, "Aufnahme"=>17, "GD"=>1.65, "HS"=>10, "gp_id"=>50012014}}
    obj.data = data
    created_at = Time.at(1629042224.760675)
    updated_at = Time.at(1629119617.668389)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012014] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012014] = id
  end
end
created_at = Time.at(1629042224.7637818)
updated_at = Time.at(1629119617.7511082)
obj_was = GameParticipation.where("id"=>50012015, "game_id"=>50006135, "player_id"=>249, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>17, "gd"=>0.94, "hs"=>4, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006135, "player_id"=>249, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>17, "gd"=>0.94, "hs"=>4, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006135, "player_id"=>249, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>17, "gd"=>0.94, "hs"=>4, "gname"=>nil)
    obj.game_id = game_id_map[50006135] if game_id_map[50006135].present?
    data = {"results"=>{"Gr."=>"group1:2-8", "Ergebnis"=>16, "Aufnahme"=>17, "GD"=>0.94, "HS"=>4, "gp_id"=>50012015}}
    obj.data = data
    created_at = Time.at(1629042224.7637818)
    updated_at = Time.at(1629119617.7511082)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012015] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012015] = id
  end
end
created_at = Time.at(1629042224.77633)
updated_at = Time.at(1629120595.330726)
obj_was = GameParticipation.where("id"=>50012016, "game_id"=>50006136, "player_id"=>255, "role"=>"playera", "points"=>0, "result"=>11, "innings"=>10, "gd"=>1.1, "hs"=>3, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006136, "player_id"=>255, "role"=>"playera", "points"=>0, "result"=>11, "innings"=>10, "gd"=>1.1, "hs"=>3, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006136, "player_id"=>255, "role"=>"playera", "points"=>0, "result"=>11, "innings"=>10, "gd"=>1.1, "hs"=>3, "gname"=>nil)
    obj.game_id = game_id_map[50006136] if game_id_map[50006136].present?
    data = {"results"=>{"Gr."=>"group1:3-4", "Ergebnis"=>11, "Aufnahme"=>10, "GD"=>1.1, "HS"=>3, "gp_id"=>50012016}}
    obj.data = data
    created_at = Time.at(1629042224.77633)
    updated_at = Time.at(1629120595.330726)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012016] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012016] = id
  end
end
created_at = Time.at(1629042224.7824771)
updated_at = Time.at(1629120595.411952)
obj_was = GameParticipation.where("id"=>50012017, "game_id"=>50006136, "player_id"=>266, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>10, "gd"=>3.2, "hs"=>16, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006136, "player_id"=>266, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>10, "gd"=>3.2, "hs"=>16, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006136, "player_id"=>266, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>10, "gd"=>3.2, "hs"=>16, "gname"=>nil)
    obj.game_id = game_id_map[50006136] if game_id_map[50006136].present?
    data = {"results"=>{"Gr."=>"group1:3-4", "Ergebnis"=>32, "Aufnahme"=>10, "GD"=>3.2, "HS"=>16, "gp_id"=>50012017}}
    obj.data = data
    created_at = Time.at(1629042224.7824771)
    updated_at = Time.at(1629120595.411952)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012017] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012017] = id
  end
end
created_at = Time.at(1629042224.794647)
updated_at = Time.at(1629118522.7181041)
obj_was = GameParticipation.where("id"=>50012018, "game_id"=>50006137, "player_id"=>255, "role"=>"playera", "points"=>0, "result"=>48, "innings"=>14, "gd"=>3.43, "hs"=>14, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006137, "player_id"=>255, "role"=>"playera", "points"=>0, "result"=>48, "innings"=>14, "gd"=>3.43, "hs"=>14, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006137, "player_id"=>255, "role"=>"playera", "points"=>0, "result"=>48, "innings"=>14, "gd"=>3.43, "hs"=>14, "gname"=>nil)
    obj.game_id = game_id_map[50006137] if game_id_map[50006137].present?
    data = {"results"=>{"Gr."=>"group1:3-5", "Ergebnis"=>48, "Aufnahme"=>14, "GD"=>3.43, "HS"=>14, "gp_id"=>50012018}}
    obj.data = data
    created_at = Time.at(1629042224.794647)
    updated_at = Time.at(1629118522.7181041)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012018] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012018] = id
  end
end
created_at = Time.at(1629042224.801305)
updated_at = Time.at(1629118522.8476841)
obj_was = GameParticipation.where("id"=>50012019, "game_id"=>50006137, "player_id"=>254, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>14, "gd"=>1.14, "hs"=>6, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006137, "player_id"=>254, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>14, "gd"=>1.14, "hs"=>6, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006137, "player_id"=>254, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>14, "gd"=>1.14, "hs"=>6, "gname"=>nil)
    obj.game_id = game_id_map[50006137] if game_id_map[50006137].present?
    data = {"results"=>{"Gr."=>"group1:3-5", "Ergebnis"=>16, "Aufnahme"=>14, "GD"=>1.14, "HS"=>6, "gp_id"=>50012019}}
    obj.data = data
    created_at = Time.at(1629042224.801305)
    updated_at = Time.at(1629118522.8476841)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012019] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012019] = id
  end
end
created_at = Time.at(1629042224.814284)
updated_at = Time.at(1629123611.1012878)
obj_was = GameParticipation.where("id"=>50012020, "game_id"=>50006138, "player_id"=>255, "role"=>"playera", "points"=>0, "result"=>39, "innings"=>10, "gd"=>3.9, "hs"=>10, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006138, "player_id"=>255, "role"=>"playera", "points"=>0, "result"=>39, "innings"=>10, "gd"=>3.9, "hs"=>10, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006138, "player_id"=>255, "role"=>"playera", "points"=>0, "result"=>39, "innings"=>10, "gd"=>3.9, "hs"=>10, "gname"=>nil)
    obj.game_id = game_id_map[50006138] if game_id_map[50006138].present?
    data = {"results"=>{"Gr."=>"group1:3-6", "Ergebnis"=>39, "Aufnahme"=>10, "GD"=>3.9, "HS"=>10, "gp_id"=>50012020}}
    obj.data = data
    created_at = Time.at(1629042224.814284)
    updated_at = Time.at(1629123611.1012878)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012020] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012020] = id
  end
end
created_at = Time.at(1629042224.818379)
updated_at = Time.at(1629123611.230873)
obj_was = GameParticipation.where("id"=>50012021, "game_id"=>50006138, "player_id"=>247, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>10, "gd"=>1.6, "hs"=>4, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006138, "player_id"=>247, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>10, "gd"=>1.6, "hs"=>4, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006138, "player_id"=>247, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>10, "gd"=>1.6, "hs"=>4, "gname"=>nil)
    obj.game_id = game_id_map[50006138] if game_id_map[50006138].present?
    data = {"results"=>{"Gr."=>"group1:3-6", "Ergebnis"=>16, "Aufnahme"=>10, "GD"=>1.6, "HS"=>4, "gp_id"=>50012021}}
    obj.data = data
    created_at = Time.at(1629042224.818379)
    updated_at = Time.at(1629123611.230873)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012021] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012021] = id
  end
end
created_at = Time.at(1629042224.8281212)
updated_at = Time.at(1629042224.8281212)
obj_was = GameParticipation.where("id"=>50012022, "game_id"=>50006139, "player_id"=>255, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006139, "player_id"=>255, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006139, "player_id"=>255, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006139] if game_id_map[50006139].present?
    created_at = Time.at(1629042224.8281212)
    updated_at = Time.at(1629042224.8281212)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012022] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012022] = id
  end
end
created_at = Time.at(1629042224.8333561)
updated_at = Time.at(1629042224.8333561)
obj_was = GameParticipation.where("id"=>50012023, "game_id"=>50006139, "player_id"=>263, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006139, "player_id"=>263, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006139, "player_id"=>263, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006139] if game_id_map[50006139].present?
    created_at = Time.at(1629042224.8333561)
    updated_at = Time.at(1629042224.8333561)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012023] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012023] = id
  end
end
created_at = Time.at(1629042224.840383)
updated_at = Time.at(1630140533.866496)
obj_was = GameParticipation.where("id"=>50012024, "game_id"=>50006140, "player_id"=>255, "role"=>"playerb", "points"=>0, "result"=>9, "innings"=>6, "gd"=>1.5, "hs"=>3, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006140, "player_id"=>255, "role"=>"playerb", "points"=>0, "result"=>9, "innings"=>6, "gd"=>1.5, "hs"=>3, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006140, "player_id"=>255, "role"=>"playerb", "points"=>0, "result"=>9, "innings"=>6, "gd"=>1.5, "hs"=>3, "gname"=>nil)
    obj.game_id = game_id_map[50006140] if game_id_map[50006140].present?
    data = {"results"=>{"Gr."=>"group1:3-8", "Ergebnis"=>9, "Aufnahme"=>6, "GD"=>1.5, "HS"=>3, "gp_id"=>50012024}}
    obj.data = data
    created_at = Time.at(1629042224.840383)
    updated_at = Time.at(1630140533.866496)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012024] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012024] = id
  end
end
created_at = Time.at(1629042224.845356)
updated_at = Time.at(1630140533.793256)
obj_was = GameParticipation.where("id"=>50012025, "game_id"=>50006140, "player_id"=>249, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>6, "gd"=>2.67, "hs"=>8, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006140, "player_id"=>249, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>6, "gd"=>2.67, "hs"=>8, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006140, "player_id"=>249, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>6, "gd"=>2.67, "hs"=>8, "gname"=>nil)
    obj.game_id = game_id_map[50006140] if game_id_map[50006140].present?
    data = {"results"=>{"Gr."=>"group1:3-8", "Ergebnis"=>16, "Aufnahme"=>6, "GD"=>2.67, "HS"=>8, "gp_id"=>50012025}}
    obj.data = data
    created_at = Time.at(1629042224.845356)
    updated_at = Time.at(1630140533.793256)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012025] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012025] = id
  end
end
created_at = Time.at(1629042224.863893)
updated_at = Time.at(1629123140.676988)
obj_was = GameParticipation.where("id"=>50012026, "game_id"=>50006141, "player_id"=>266, "role"=>"playera", "points"=>0, "result"=>5, "innings"=>9, "gd"=>0.56, "hs"=>1, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006141, "player_id"=>266, "role"=>"playera", "points"=>0, "result"=>5, "innings"=>9, "gd"=>0.56, "hs"=>1, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006141, "player_id"=>266, "role"=>"playera", "points"=>0, "result"=>5, "innings"=>9, "gd"=>0.56, "hs"=>1, "gname"=>nil)
    obj.game_id = game_id_map[50006141] if game_id_map[50006141].present?
    data = {"results"=>{"Gr."=>"group1:4-5", "Ergebnis"=>5, "Aufnahme"=>9, "GD"=>0.56, "HS"=>1, "gp_id"=>50012026}}
    obj.data = data
    created_at = Time.at(1629042224.863893)
    updated_at = Time.at(1629123140.676988)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012026] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012026] = id
  end
end
created_at = Time.at(1629042224.8722298)
updated_at = Time.at(1629123140.7991621)
obj_was = GameParticipation.where("id"=>50012027, "game_id"=>50006141, "player_id"=>254, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>9, "gd"=>1.78, "hs"=>5, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006141, "player_id"=>254, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>9, "gd"=>1.78, "hs"=>5, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006141, "player_id"=>254, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>9, "gd"=>1.78, "hs"=>5, "gname"=>nil)
    obj.game_id = game_id_map[50006141] if game_id_map[50006141].present?
    data = {"results"=>{"Gr."=>"group1:4-5", "Ergebnis"=>16, "Aufnahme"=>9, "GD"=>1.78, "HS"=>5, "gp_id"=>50012027}}
    obj.data = data
    created_at = Time.at(1629042224.8722298)
    updated_at = Time.at(1629123140.7991621)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012027] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012027] = id
  end
end
created_at = Time.at(1629042224.882106)
updated_at = Time.at(1629120791.161696)
obj_was = GameParticipation.where("id"=>50012028, "game_id"=>50006142, "player_id"=>266, "role"=>"playera", "points"=>2, "result"=>32, "innings"=>6, "gd"=>5.33, "hs"=>8, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006142, "player_id"=>266, "role"=>"playera", "points"=>2, "result"=>32, "innings"=>6, "gd"=>5.33, "hs"=>8, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006142, "player_id"=>266, "role"=>"playera", "points"=>2, "result"=>32, "innings"=>6, "gd"=>5.33, "hs"=>8, "gname"=>nil)
    obj.game_id = game_id_map[50006142] if game_id_map[50006142].present?
    data = {"results"=>{"Gr."=>"group1:4-6", "Ergebnis"=>32, "Aufnahme"=>6, "GD"=>5.33, "HS"=>8, "gp_id"=>50012028}}
    obj.data = data
    created_at = Time.at(1629042224.882106)
    updated_at = Time.at(1629120791.161696)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012028] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012028] = id
  end
end
created_at = Time.at(1629042224.887286)
updated_at = Time.at(1629120791.245484)
obj_was = GameParticipation.where("id"=>50012029, "game_id"=>50006142, "player_id"=>247, "role"=>"playerb", "points"=>0, "result"=>5, "innings"=>6, "gd"=>0.83, "hs"=>2, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006142, "player_id"=>247, "role"=>"playerb", "points"=>0, "result"=>5, "innings"=>6, "gd"=>0.83, "hs"=>2, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006142, "player_id"=>247, "role"=>"playerb", "points"=>0, "result"=>5, "innings"=>6, "gd"=>0.83, "hs"=>2, "gname"=>nil)
    obj.game_id = game_id_map[50006142] if game_id_map[50006142].present?
    data = {"results"=>{"Gr."=>"group1:4-6", "Ergebnis"=>5, "Aufnahme"=>6, "GD"=>0.83, "HS"=>2, "gp_id"=>50012029}}
    obj.data = data
    created_at = Time.at(1629042224.887286)
    updated_at = Time.at(1629120791.245484)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012029] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012029] = id
  end
end
created_at = Time.at(1629042224.90513)
updated_at = Time.at(1629042224.90513)
obj_was = GameParticipation.where("id"=>50012030, "game_id"=>50006143, "player_id"=>266, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006143, "player_id"=>266, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006143, "player_id"=>266, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006143] if game_id_map[50006143].present?
    created_at = Time.at(1629042224.90513)
    updated_at = Time.at(1629042224.90513)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012030] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012030] = id
  end
end
created_at = Time.at(1629042224.910828)
updated_at = Time.at(1629042224.910828)
obj_was = GameParticipation.where("id"=>50012031, "game_id"=>50006143, "player_id"=>263, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006143, "player_id"=>263, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006143, "player_id"=>263, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006143] if game_id_map[50006143].present?
    created_at = Time.at(1629042224.910828)
    updated_at = Time.at(1629042224.910828)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012031] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012031] = id
  end
end
created_at = Time.at(1629042224.919749)
updated_at = Time.at(1630140934.7478452)
obj_was = GameParticipation.where("id"=>50012032, "game_id"=>50006144, "player_id"=>266, "role"=>"playerb", "points"=>0, "result"=>16, "innings"=>6, "gd"=>2.67, "hs"=>12, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006144, "player_id"=>266, "role"=>"playerb", "points"=>0, "result"=>16, "innings"=>6, "gd"=>2.67, "hs"=>12, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006144, "player_id"=>266, "role"=>"playerb", "points"=>0, "result"=>16, "innings"=>6, "gd"=>2.67, "hs"=>12, "gname"=>nil)
    obj.game_id = game_id_map[50006144] if game_id_map[50006144].present?
    data = {"results"=>{"Gr."=>"group1:4-8", "Ergebnis"=>16, "Aufnahme"=>6, "GD"=>2.67, "HS"=>12, "gp_id"=>50012032}}
    obj.data = data
    created_at = Time.at(1629042224.919749)
    updated_at = Time.at(1630140934.7478452)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012032] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012032] = id
  end
end
created_at = Time.at(1629042224.928638)
updated_at = Time.at(1630140934.676023)
obj_was = GameParticipation.where("id"=>50012033, "game_id"=>50006144, "player_id"=>249, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>6, "gd"=>2.67, "hs"=>4, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006144, "player_id"=>249, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>6, "gd"=>2.67, "hs"=>4, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006144, "player_id"=>249, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>6, "gd"=>2.67, "hs"=>4, "gname"=>nil)
    obj.game_id = game_id_map[50006144] if game_id_map[50006144].present?
    data = {"results"=>{"Gr."=>"group1:4-8", "Ergebnis"=>16, "Aufnahme"=>6, "GD"=>2.67, "HS"=>4, "gp_id"=>50012033}}
    obj.data = data
    created_at = Time.at(1629042224.928638)
    updated_at = Time.at(1630140934.676023)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012033] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012033] = id
  end
end
created_at = Time.at(1629042224.941077)
updated_at = Time.at(1629122480.625794)
obj_was = GameParticipation.where("id"=>50012034, "game_id"=>50006145, "player_id"=>254, "role"=>"playera", "points"=>2, "result"=>4, "innings"=>2, "gd"=>2.0, "hs"=>2, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006145, "player_id"=>254, "role"=>"playera", "points"=>2, "result"=>4, "innings"=>2, "gd"=>2.0, "hs"=>2, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006145, "player_id"=>254, "role"=>"playera", "points"=>2, "result"=>4, "innings"=>2, "gd"=>2.0, "hs"=>2, "gname"=>nil)
    obj.game_id = game_id_map[50006145] if game_id_map[50006145].present?
    data = {"results"=>{"Gr."=>"group1:5-6", "Ergebnis"=>4, "Aufnahme"=>2, "GD"=>2.0, "HS"=>2, "gp_id"=>50012034}}
    obj.data = data
    created_at = Time.at(1629042224.941077)
    updated_at = Time.at(1629122480.625794)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012034] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012034] = id
  end
end
created_at = Time.at(1629042224.944381)
updated_at = Time.at(1629122480.777788)
obj_was = GameParticipation.where("id"=>50012035, "game_id"=>50006145, "player_id"=>247, "role"=>"playerb", "points"=>0, "result"=>2, "innings"=>1, "gd"=>2.0, "hs"=>2, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006145, "player_id"=>247, "role"=>"playerb", "points"=>0, "result"=>2, "innings"=>1, "gd"=>2.0, "hs"=>2, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006145, "player_id"=>247, "role"=>"playerb", "points"=>0, "result"=>2, "innings"=>1, "gd"=>2.0, "hs"=>2, "gname"=>nil)
    obj.game_id = game_id_map[50006145] if game_id_map[50006145].present?
    data = {"results"=>{"Gr."=>"group1:5-6", "Ergebnis"=>2, "Aufnahme"=>1, "GD"=>2.0, "HS"=>2, "gp_id"=>50012035}}
    obj.data = data
    created_at = Time.at(1629042224.944381)
    updated_at = Time.at(1629122480.777788)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012035] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012035] = id
  end
end
created_at = Time.at(1629042224.9609668)
updated_at = Time.at(1629219496.494068)
obj_was = GameParticipation.where("id"=>50012036, "game_id"=>50006146, "player_id"=>254, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>10, "gd"=>1.6, "hs"=>6, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006146, "player_id"=>254, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>10, "gd"=>1.6, "hs"=>6, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006146, "player_id"=>254, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>10, "gd"=>1.6, "hs"=>6, "gname"=>nil)
    obj.game_id = game_id_map[50006146] if game_id_map[50006146].present?
    data = {"results"=>{"Gr."=>"group1:5-7", "Ergebnis"=>16, "Aufnahme"=>10, "GD"=>1.6, "HS"=>6, "gp_id"=>50012036}}
    obj.data = data
    created_at = Time.at(1629042224.9609668)
    updated_at = Time.at(1629219496.494068)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012036] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012036] = id
  end
end
created_at = Time.at(1629042224.964618)
updated_at = Time.at(1629219496.668479)
obj_was = GameParticipation.where("id"=>50012037, "game_id"=>50006146, "player_id"=>263, "role"=>"playerb", "points"=>0, "result"=>10, "innings"=>10, "gd"=>1.0, "hs"=>5, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006146, "player_id"=>263, "role"=>"playerb", "points"=>0, "result"=>10, "innings"=>10, "gd"=>1.0, "hs"=>5, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006146, "player_id"=>263, "role"=>"playerb", "points"=>0, "result"=>10, "innings"=>10, "gd"=>1.0, "hs"=>5, "gname"=>nil)
    obj.game_id = game_id_map[50006146] if game_id_map[50006146].present?
    data = {"results"=>{"Gr."=>"group1:5-7", "Ergebnis"=>10, "Aufnahme"=>10, "GD"=>1.0, "HS"=>5, "gp_id"=>50012037}}
    obj.data = data
    created_at = Time.at(1629042224.964618)
    updated_at = Time.at(1629219496.668479)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012037] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012037] = id
  end
end
created_at = Time.at(1629042224.9853199)
updated_at = Time.at(1629119287.928894)
obj_was = GameParticipation.where("id"=>50012038, "game_id"=>50006147, "player_id"=>254, "role"=>"playera", "points"=>0, "result"=>11, "innings"=>11, "gd"=>1.0, "hs"=>4, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006147, "player_id"=>254, "role"=>"playera", "points"=>0, "result"=>11, "innings"=>11, "gd"=>1.0, "hs"=>4, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006147, "player_id"=>254, "role"=>"playera", "points"=>0, "result"=>11, "innings"=>11, "gd"=>1.0, "hs"=>4, "gname"=>nil)
    obj.game_id = game_id_map[50006147] if game_id_map[50006147].present?
    data = {"results"=>{"Gr."=>"group1:5-8", "Ergebnis"=>11, "Aufnahme"=>11, "GD"=>1.0, "HS"=>4, "gp_id"=>50012038}}
    obj.data = data
    created_at = Time.at(1629042224.9853199)
    updated_at = Time.at(1629119287.928894)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012038] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012038] = id
  end
end
created_at = Time.at(1629042224.98871)
updated_at = Time.at(1629119288.077176)
obj_was = GameParticipation.where("id"=>50012039, "game_id"=>50006147, "player_id"=>249, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>11, "gd"=>1.45, "hs"=>2, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006147, "player_id"=>249, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>11, "gd"=>1.45, "hs"=>2, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006147, "player_id"=>249, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>11, "gd"=>1.45, "hs"=>2, "gname"=>nil)
    obj.game_id = game_id_map[50006147] if game_id_map[50006147].present?
    data = {"results"=>{"Gr."=>"group1:5-8", "Ergebnis"=>16, "Aufnahme"=>11, "GD"=>1.45, "HS"=>2, "gp_id"=>50012039}}
    obj.data = data
    created_at = Time.at(1629042224.98871)
    updated_at = Time.at(1629119288.077176)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012039] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012039] = id
  end
end
created_at = Time.at(1629042224.999506)
updated_at = Time.at(1629124573.954732)
obj_was = GameParticipation.where("id"=>50012040, "game_id"=>50006148, "player_id"=>247, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>14, "gd"=>1.14, "hs"=>6, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006148, "player_id"=>247, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>14, "gd"=>1.14, "hs"=>6, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006148, "player_id"=>247, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>14, "gd"=>1.14, "hs"=>6, "gname"=>nil)
    obj.game_id = game_id_map[50006148] if game_id_map[50006148].present?
    data = {"results"=>{"Gr."=>"group1:6-7", "Ergebnis"=>16, "Aufnahme"=>14, "GD"=>1.14, "HS"=>6, "gp_id"=>50012040}}
    obj.data = data
    created_at = Time.at(1629042224.999506)
    updated_at = Time.at(1629124573.954732)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012040] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012040] = id
  end
end
created_at = Time.at(1629042225.003144)
updated_at = Time.at(1629124574.045556)
obj_was = GameParticipation.where("id"=>50012041, "game_id"=>50006148, "player_id"=>263, "role"=>"playerb", "points"=>0, "result"=>5, "innings"=>14, "gd"=>0.36, "hs"=>2, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006148, "player_id"=>263, "role"=>"playerb", "points"=>0, "result"=>5, "innings"=>14, "gd"=>0.36, "hs"=>2, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006148, "player_id"=>263, "role"=>"playerb", "points"=>0, "result"=>5, "innings"=>14, "gd"=>0.36, "hs"=>2, "gname"=>nil)
    obj.game_id = game_id_map[50006148] if game_id_map[50006148].present?
    data = {"results"=>{"Gr."=>"group1:6-7", "Ergebnis"=>5, "Aufnahme"=>14, "GD"=>0.36, "HS"=>2, "gp_id"=>50012041}}
    obj.data = data
    created_at = Time.at(1629042225.003144)
    updated_at = Time.at(1629124574.045556)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012041] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012041] = id
  end
end
created_at = Time.at(1629042225.018147)
updated_at = Time.at(1629119789.9941509)
obj_was = GameParticipation.where("id"=>50012042, "game_id"=>50006149, "player_id"=>247, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>7, "gd"=>2.29, "hs"=>3, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006149, "player_id"=>247, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>7, "gd"=>2.29, "hs"=>3, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006149, "player_id"=>247, "role"=>"playera", "points"=>2, "result"=>16, "innings"=>7, "gd"=>2.29, "hs"=>3, "gname"=>nil)
    obj.game_id = game_id_map[50006149] if game_id_map[50006149].present?
    data = {"results"=>{"Gr."=>"group1:6-8", "Ergebnis"=>16, "Aufnahme"=>7, "GD"=>2.29, "HS"=>3, "gp_id"=>50012042}}
    obj.data = data
    created_at = Time.at(1629042225.018147)
    updated_at = Time.at(1629119789.9941509)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012042] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012042] = id
  end
end
created_at = Time.at(1629042225.02717)
updated_at = Time.at(1629119790.077077)
obj_was = GameParticipation.where("id"=>50012043, "game_id"=>50006149, "player_id"=>249, "role"=>"playerb", "points"=>0, "result"=>3, "innings"=>7, "gd"=>0.43, "hs"=>1, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006149, "player_id"=>249, "role"=>"playerb", "points"=>0, "result"=>3, "innings"=>7, "gd"=>0.43, "hs"=>1, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006149, "player_id"=>249, "role"=>"playerb", "points"=>0, "result"=>3, "innings"=>7, "gd"=>0.43, "hs"=>1, "gname"=>nil)
    obj.game_id = game_id_map[50006149] if game_id_map[50006149].present?
    data = {"results"=>{"Gr."=>"group1:6-8", "Ergebnis"=>3, "Aufnahme"=>7, "GD"=>0.43, "HS"=>1, "gp_id"=>50012043}}
    obj.data = data
    created_at = Time.at(1629042225.02717)
    updated_at = Time.at(1629119790.077077)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012043] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012043] = id
  end
end
created_at = Time.at(1629042225.04187)
updated_at = Time.at(1629119963.3051908)
obj_was = GameParticipation.where("id"=>50012044, "game_id"=>50006150, "player_id"=>263, "role"=>"playera", "points"=>0, "result"=>7, "innings"=>15, "gd"=>0.47, "hs"=>4, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006150, "player_id"=>263, "role"=>"playera", "points"=>0, "result"=>7, "innings"=>15, "gd"=>0.47, "hs"=>4, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006150, "player_id"=>263, "role"=>"playera", "points"=>0, "result"=>7, "innings"=>15, "gd"=>0.47, "hs"=>4, "gname"=>nil)
    obj.game_id = game_id_map[50006150] if game_id_map[50006150].present?
    data = {"results"=>{"Gr."=>"group1:7-8", "Ergebnis"=>7, "Aufnahme"=>15, "GD"=>0.47, "HS"=>4, "gp_id"=>50012044}}
    obj.data = data
    created_at = Time.at(1629042225.04187)
    updated_at = Time.at(1629119963.3051908)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012044] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012044] = id
  end
end
created_at = Time.at(1629042225.0480828)
updated_at = Time.at(1629119963.3873012)
obj_was = GameParticipation.where("id"=>50012045, "game_id"=>50006150, "player_id"=>249, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>15, "gd"=>1.07, "hs"=>3, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006150, "player_id"=>249, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>15, "gd"=>1.07, "hs"=>3, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006150, "player_id"=>249, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>15, "gd"=>1.07, "hs"=>3, "gname"=>nil)
    obj.game_id = game_id_map[50006150] if game_id_map[50006150].present?
    data = {"results"=>{"Gr."=>"group1:7-8", "Ergebnis"=>16, "Aufnahme"=>15, "GD"=>1.07, "HS"=>3, "gp_id"=>50012045}}
    obj.data = data
    created_at = Time.at(1629042225.0480828)
    updated_at = Time.at(1629119963.3873012)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012045] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012045] = id
  end
end
created_at = Time.at(1629042225.061973)
updated_at = Time.at(1629042225.061973)
obj_was = GameParticipation.where("id"=>50012046, "game_id"=>50006151, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006151, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006151, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006151] if game_id_map[50006151].present?
    created_at = Time.at(1629042225.061973)
    updated_at = Time.at(1629042225.061973)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012046] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012046] = id
  end
end
created_at = Time.at(1629042225.068676)
updated_at = Time.at(1629042225.068676)
obj_was = GameParticipation.where("id"=>50012047, "game_id"=>50006151, "player_id"=>267, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006151, "player_id"=>267, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006151, "player_id"=>267, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006151] if game_id_map[50006151].present?
    created_at = Time.at(1629042225.068676)
    updated_at = Time.at(1629042225.068676)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012047] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012047] = id
  end
end
created_at = Time.at(1629042225.081963)
updated_at = Time.at(1629042225.081963)
obj_was = GameParticipation.where("id"=>50012048, "game_id"=>50006152, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006152, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006152, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006152] if game_id_map[50006152].present?
    created_at = Time.at(1629042225.081963)
    updated_at = Time.at(1629042225.081963)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012048] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012048] = id
  end
end
created_at = Time.at(1629042225.086695)
updated_at = Time.at(1629042225.086695)
obj_was = GameParticipation.where("id"=>50012049, "game_id"=>50006152, "player_id"=>262, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006152, "player_id"=>262, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006152, "player_id"=>262, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006152] if game_id_map[50006152].present?
    created_at = Time.at(1629042225.086695)
    updated_at = Time.at(1629042225.086695)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012049] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012049] = id
  end
end
created_at = Time.at(1629042225.101025)
updated_at = Time.at(1629042225.101025)
obj_was = GameParticipation.where("id"=>50012050, "game_id"=>50006153, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006153, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006153, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006153] if game_id_map[50006153].present?
    created_at = Time.at(1629042225.101025)
    updated_at = Time.at(1629042225.101025)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012050] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012050] = id
  end
end
created_at = Time.at(1629042225.105527)
updated_at = Time.at(1629042225.105527)
obj_was = GameParticipation.where("id"=>50012051, "game_id"=>50006153, "player_id"=>252, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006153, "player_id"=>252, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006153, "player_id"=>252, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006153] if game_id_map[50006153].present?
    created_at = Time.at(1629042225.105527)
    updated_at = Time.at(1629042225.105527)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012051] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012051] = id
  end
end
created_at = Time.at(1629042225.121391)
updated_at = Time.at(1629042225.121391)
obj_was = GameParticipation.where("id"=>50012052, "game_id"=>50006154, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006154, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006154, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006154] if game_id_map[50006154].present?
    created_at = Time.at(1629042225.121391)
    updated_at = Time.at(1629042225.121391)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012052] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012052] = id
  end
end
created_at = Time.at(1629042225.12718)
updated_at = Time.at(1629042225.12718)
obj_was = GameParticipation.where("id"=>50012053, "game_id"=>50006154, "player_id"=>50000001, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006154, "player_id"=>50000001, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006154, "player_id"=>50000001, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006154] if game_id_map[50006154].present?
    created_at = Time.at(1629042225.12718)
    updated_at = Time.at(1629042225.12718)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012053] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012053] = id
  end
end
created_at = Time.at(1629042225.1409469)
updated_at = Time.at(1629042225.1409469)
obj_was = GameParticipation.where("id"=>50012054, "game_id"=>50006155, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006155, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006155, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006155] if game_id_map[50006155].present?
    created_at = Time.at(1629042225.1409469)
    updated_at = Time.at(1629042225.1409469)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012054] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012054] = id
  end
end
created_at = Time.at(1629042225.1445389)
updated_at = Time.at(1629042225.1445389)
obj_was = GameParticipation.where("id"=>50012055, "game_id"=>50006155, "player_id"=>256, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006155, "player_id"=>256, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006155, "player_id"=>256, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006155] if game_id_map[50006155].present?
    created_at = Time.at(1629042225.1445389)
    updated_at = Time.at(1629042225.1445389)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012055] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012055] = id
  end
end
created_at = Time.at(1629042225.169059)
updated_at = Time.at(1629042225.169059)
obj_was = GameParticipation.where("id"=>50012056, "game_id"=>50006156, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006156, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006156, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006156] if game_id_map[50006156].present?
    created_at = Time.at(1629042225.169059)
    updated_at = Time.at(1629042225.169059)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012056] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012056] = id
  end
end
created_at = Time.at(1629042225.1765592)
updated_at = Time.at(1629042225.1765592)
obj_was = GameParticipation.where("id"=>50012057, "game_id"=>50006156, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006156, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006156, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006156] if game_id_map[50006156].present?
    created_at = Time.at(1629042225.1765592)
    updated_at = Time.at(1629042225.1765592)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012057] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012057] = id
  end
end
created_at = Time.at(1629042225.1927738)
updated_at = Time.at(1629042225.1927738)
obj_was = GameParticipation.where("id"=>50012058, "game_id"=>50006157, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006157, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006157, "player_id"=>265, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006157] if game_id_map[50006157].present?
    created_at = Time.at(1629042225.1927738)
    updated_at = Time.at(1629042225.1927738)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012058] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012058] = id
  end
end
created_at = Time.at(1629042225.1990972)
updated_at = Time.at(1629042225.1990972)
obj_was = GameParticipation.where("id"=>50012059, "game_id"=>50006157, "player_id"=>260, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006157, "player_id"=>260, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006157, "player_id"=>260, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006157] if game_id_map[50006157].present?
    created_at = Time.at(1629042225.1990972)
    updated_at = Time.at(1629042225.1990972)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012059] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012059] = id
  end
end
created_at = Time.at(1629042225.2136588)
updated_at = Time.at(1629221133.112648)
obj_was = GameParticipation.where("id"=>50012060, "game_id"=>50006158, "player_id"=>267, "role"=>"playera", "points"=>0, "result"=>84, "innings"=>7, "gd"=>12.0, "hs"=>55, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006158, "player_id"=>267, "role"=>"playera", "points"=>0, "result"=>84, "innings"=>7, "gd"=>12.0, "hs"=>55, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006158, "player_id"=>267, "role"=>"playera", "points"=>0, "result"=>84, "innings"=>7, "gd"=>12.0, "hs"=>55, "gname"=>nil)
    obj.game_id = game_id_map[50006158] if game_id_map[50006158].present?
    data = {"results"=>{"Gr."=>"group2:2-3", "Ergebnis"=>84, "Aufnahme"=>7, "GD"=>12.0, "HS"=>55, "gp_id"=>50012060}}
    obj.data = data
    created_at = Time.at(1629042225.2136588)
    updated_at = Time.at(1629221133.112648)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012060] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012060] = id
  end
end
created_at = Time.at(1629042225.219854)
updated_at = Time.at(1629221133.250603)
obj_was = GameParticipation.where("id"=>50012061, "game_id"=>50006158, "player_id"=>262, "role"=>"playerb", "points"=>2, "result"=>60, "innings"=>7, "gd"=>8.57, "hs"=>21, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006158, "player_id"=>262, "role"=>"playerb", "points"=>2, "result"=>60, "innings"=>7, "gd"=>8.57, "hs"=>21, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006158, "player_id"=>262, "role"=>"playerb", "points"=>2, "result"=>60, "innings"=>7, "gd"=>8.57, "hs"=>21, "gname"=>nil)
    obj.game_id = game_id_map[50006158] if game_id_map[50006158].present?
    data = {"results"=>{"Gr."=>"group2:2-3", "Ergebnis"=>60, "Aufnahme"=>7, "GD"=>8.57, "HS"=>21, "gp_id"=>50012061}}
    obj.data = data
    created_at = Time.at(1629042225.219854)
    updated_at = Time.at(1629221133.250603)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012061] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012061] = id
  end
end
created_at = Time.at(1629042225.2269619)
updated_at = Time.at(1629220344.7697291)
obj_was = GameParticipation.where("id"=>50012062, "game_id"=>50006159, "player_id"=>267, "role"=>"playera", "points"=>0, "result"=>70, "innings"=>15, "gd"=>4.67, "hs"=>20, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006159, "player_id"=>267, "role"=>"playera", "points"=>0, "result"=>70, "innings"=>15, "gd"=>4.67, "hs"=>20, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006159, "player_id"=>267, "role"=>"playera", "points"=>0, "result"=>70, "innings"=>15, "gd"=>4.67, "hs"=>20, "gname"=>nil)
    obj.game_id = game_id_map[50006159] if game_id_map[50006159].present?
    data = {"results"=>{"Gr."=>"group2:2-4", "Ergebnis"=>70, "Aufnahme"=>15, "GD"=>4.67, "HS"=>20, "gp_id"=>50012062}}
    obj.data = data
    created_at = Time.at(1629042225.2269619)
    updated_at = Time.at(1629220344.7697291)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012062] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012062] = id
  end
end
created_at = Time.at(1629042225.230124)
updated_at = Time.at(1629220344.962055)
obj_was = GameParticipation.where("id"=>50012063, "game_id"=>50006159, "player_id"=>252, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>15, "gd"=>2.13, "hs"=>6, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006159, "player_id"=>252, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>15, "gd"=>2.13, "hs"=>6, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006159, "player_id"=>252, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>15, "gd"=>2.13, "hs"=>6, "gname"=>nil)
    obj.game_id = game_id_map[50006159] if game_id_map[50006159].present?
    data = {"results"=>{"Gr."=>"group2:2-4", "Ergebnis"=>32, "Aufnahme"=>15, "GD"=>2.13, "HS"=>6, "gp_id"=>50012063}}
    obj.data = data
    created_at = Time.at(1629042225.230124)
    updated_at = Time.at(1629220344.962055)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012063] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012063] = id
  end
end
created_at = Time.at(1629042225.2413561)
updated_at = Time.at(1629221405.818766)
obj_was = GameParticipation.where("id"=>50012064, "game_id"=>50006160, "player_id"=>267, "role"=>"playera", "points"=>2, "result"=>150, "innings"=>18, "gd"=>8.33, "hs"=>51, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006160, "player_id"=>267, "role"=>"playera", "points"=>2, "result"=>150, "innings"=>18, "gd"=>8.33, "hs"=>51, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006160, "player_id"=>267, "role"=>"playera", "points"=>2, "result"=>150, "innings"=>18, "gd"=>8.33, "hs"=>51, "gname"=>nil)
    obj.game_id = game_id_map[50006160] if game_id_map[50006160].present?
    data = {"results"=>{"Gr."=>"group2:2-5", "Ergebnis"=>150, "Aufnahme"=>18, "GD"=>8.33, "HS"=>51, "gp_id"=>50012064}}
    obj.data = data
    created_at = Time.at(1629042225.2413561)
    updated_at = Time.at(1629221405.818766)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012064] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012064] = id
  end
end
created_at = Time.at(1629042225.248944)
updated_at = Time.at(1629221405.965127)
obj_was = GameParticipation.where("id"=>50012065, "game_id"=>50006160, "player_id"=>50000001, "role"=>"playerb", "points"=>0, "result"=>14, "innings"=>18, "gd"=>0.78, "hs"=>4, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006160, "player_id"=>50000001, "role"=>"playerb", "points"=>0, "result"=>14, "innings"=>18, "gd"=>0.78, "hs"=>4, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006160, "player_id"=>50000001, "role"=>"playerb", "points"=>0, "result"=>14, "innings"=>18, "gd"=>0.78, "hs"=>4, "gname"=>nil)
    obj.game_id = game_id_map[50006160] if game_id_map[50006160].present?
    data = {"results"=>{"Gr."=>"group2:2-5", "Ergebnis"=>14, "Aufnahme"=>18, "GD"=>0.78, "HS"=>4, "gp_id"=>50012065}}
    obj.data = data
    created_at = Time.at(1629042225.248944)
    updated_at = Time.at(1629221405.965127)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012065] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012065] = id
  end
end
created_at = Time.at(1629042225.26419)
updated_at = Time.at(1629224338.0090501)
obj_was = GameParticipation.where("id"=>50012066, "game_id"=>50006161, "player_id"=>267, "role"=>"playera", "points"=>0, "result"=>147, "innings"=>22, "gd"=>6.68, "hs"=>21, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006161, "player_id"=>267, "role"=>"playera", "points"=>0, "result"=>147, "innings"=>22, "gd"=>6.68, "hs"=>21, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006161, "player_id"=>267, "role"=>"playera", "points"=>0, "result"=>147, "innings"=>22, "gd"=>6.68, "hs"=>21, "gname"=>nil)
    obj.game_id = game_id_map[50006161] if game_id_map[50006161].present?
    data = {"results"=>{"Gr."=>"group2:2-6", "Ergebnis"=>147, "Aufnahme"=>22, "GD"=>6.68, "HS"=>21, "gp_id"=>50012066}}
    obj.data = data
    created_at = Time.at(1629042225.26419)
    updated_at = Time.at(1629224338.0090501)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012066] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012066] = id
  end
end
created_at = Time.at(1629042225.271876)
updated_at = Time.at(1629224338.092475)
obj_was = GameParticipation.where("id"=>50012067, "game_id"=>50006161, "player_id"=>256, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>22, "gd"=>0.73, "hs"=>2, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006161, "player_id"=>256, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>22, "gd"=>0.73, "hs"=>2, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006161, "player_id"=>256, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>22, "gd"=>0.73, "hs"=>2, "gname"=>nil)
    obj.game_id = game_id_map[50006161] if game_id_map[50006161].present?
    data = {"results"=>{"Gr."=>"group2:2-6", "Ergebnis"=>16, "Aufnahme"=>22, "GD"=>0.73, "HS"=>2, "gp_id"=>50012067}}
    obj.data = data
    created_at = Time.at(1629042225.271876)
    updated_at = Time.at(1629224338.092475)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012067] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012067] = id
  end
end
created_at = Time.at(1629042225.284448)
updated_at = Time.at(1629042225.284448)
obj_was = GameParticipation.where("id"=>50012068, "game_id"=>50006162, "player_id"=>267, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006162, "player_id"=>267, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006162, "player_id"=>267, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006162] if game_id_map[50006162].present?
    created_at = Time.at(1629042225.284448)
    updated_at = Time.at(1629042225.284448)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012068] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012068] = id
  end
end
created_at = Time.at(1629042225.290209)
updated_at = Time.at(1629042225.290209)
obj_was = GameParticipation.where("id"=>50012069, "game_id"=>50006162, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006162, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006162, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006162] if game_id_map[50006162].present?
    created_at = Time.at(1629042225.290209)
    updated_at = Time.at(1629042225.290209)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012069] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012069] = id
  end
end
created_at = Time.at(1629042225.305857)
updated_at = Time.at(1629225078.519212)
obj_was = GameParticipation.where("id"=>50012070, "game_id"=>50006163, "player_id"=>267, "role"=>"playera", "points"=>0, "result"=>78, "innings"=>10, "gd"=>7.8, "hs"=>32, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006163, "player_id"=>267, "role"=>"playera", "points"=>0, "result"=>78, "innings"=>10, "gd"=>7.8, "hs"=>32, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006163, "player_id"=>267, "role"=>"playera", "points"=>0, "result"=>78, "innings"=>10, "gd"=>7.8, "hs"=>32, "gname"=>nil)
    obj.game_id = game_id_map[50006163] if game_id_map[50006163].present?
    data = {"results"=>{"Gr."=>"group2:2-8", "Ergebnis"=>78, "Aufnahme"=>10, "GD"=>7.8, "HS"=>32, "gp_id"=>50012070}}
    obj.data = data
    created_at = Time.at(1629042225.305857)
    updated_at = Time.at(1629225078.519212)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012070] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012070] = id
  end
end
created_at = Time.at(1629042225.311219)
updated_at = Time.at(1629225078.657791)
obj_was = GameParticipation.where("id"=>50012071, "game_id"=>50006163, "player_id"=>260, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>10, "gd"=>3.2, "hs"=>11, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006163, "player_id"=>260, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>10, "gd"=>3.2, "hs"=>11, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006163, "player_id"=>260, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>10, "gd"=>3.2, "hs"=>11, "gname"=>nil)
    obj.game_id = game_id_map[50006163] if game_id_map[50006163].present?
    data = {"results"=>{"Gr."=>"group2:2-8", "Ergebnis"=>32, "Aufnahme"=>10, "GD"=>3.2, "HS"=>11, "gp_id"=>50012071}}
    obj.data = data
    created_at = Time.at(1629042225.311219)
    updated_at = Time.at(1629225078.657791)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012071] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012071] = id
  end
end
created_at = Time.at(1629042225.322321)
updated_at = Time.at(1629225498.6514392)
obj_was = GameParticipation.where("id"=>50012072, "game_id"=>50006164, "player_id"=>262, "role"=>"playera", "points"=>0, "result"=>30, "innings"=>10, "gd"=>3.0, "hs"=>11, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006164, "player_id"=>262, "role"=>"playera", "points"=>0, "result"=>30, "innings"=>10, "gd"=>3.0, "hs"=>11, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006164, "player_id"=>262, "role"=>"playera", "points"=>0, "result"=>30, "innings"=>10, "gd"=>3.0, "hs"=>11, "gname"=>nil)
    obj.game_id = game_id_map[50006164] if game_id_map[50006164].present?
    data = {"results"=>{"Gr."=>"group2:3-4", "Ergebnis"=>30, "Aufnahme"=>10, "GD"=>3.0, "HS"=>11, "gp_id"=>50012072}}
    obj.data = data
    created_at = Time.at(1629042225.322321)
    updated_at = Time.at(1629225498.6514392)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012072] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012072] = id
  end
end
created_at = Time.at(1629042225.326715)
updated_at = Time.at(1629225498.745823)
obj_was = GameParticipation.where("id"=>50012073, "game_id"=>50006164, "player_id"=>252, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>10, "gd"=>3.2, "hs"=>10, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006164, "player_id"=>252, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>10, "gd"=>3.2, "hs"=>10, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006164, "player_id"=>252, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>10, "gd"=>3.2, "hs"=>10, "gname"=>nil)
    obj.game_id = game_id_map[50006164] if game_id_map[50006164].present?
    data = {"results"=>{"Gr."=>"group2:3-4", "Ergebnis"=>32, "Aufnahme"=>10, "GD"=>3.2, "HS"=>10, "gp_id"=>50012073}}
    obj.data = data
    created_at = Time.at(1629042225.326715)
    updated_at = Time.at(1629225498.745823)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012073] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012073] = id
  end
end
created_at = Time.at(1629042225.335652)
updated_at = Time.at(1629226521.783626)
obj_was = GameParticipation.where("id"=>50012074, "game_id"=>50006165, "player_id"=>262, "role"=>"playera", "points"=>2, "result"=>60, "innings"=>14, "gd"=>4.29, "hs"=>28, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006165, "player_id"=>262, "role"=>"playera", "points"=>2, "result"=>60, "innings"=>14, "gd"=>4.29, "hs"=>28, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006165, "player_id"=>262, "role"=>"playera", "points"=>2, "result"=>60, "innings"=>14, "gd"=>4.29, "hs"=>28, "gname"=>nil)
    obj.game_id = game_id_map[50006165] if game_id_map[50006165].present?
    data = {"results"=>{"Gr."=>"group2:3-5", "Ergebnis"=>60, "Aufnahme"=>14, "GD"=>4.29, "HS"=>28, "gp_id"=>50012074}}
    obj.data = data
    created_at = Time.at(1629042225.335652)
    updated_at = Time.at(1629226521.783626)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012074] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012074] = id
  end
end
created_at = Time.at(1629042225.342038)
updated_at = Time.at(1629226521.864129)
obj_was = GameParticipation.where("id"=>50012075, "game_id"=>50006165, "player_id"=>50000001, "role"=>"playerb", "points"=>0, "result"=>15, "innings"=>14, "gd"=>1.07, "hs"=>5, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006165, "player_id"=>50000001, "role"=>"playerb", "points"=>0, "result"=>15, "innings"=>14, "gd"=>1.07, "hs"=>5, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006165, "player_id"=>50000001, "role"=>"playerb", "points"=>0, "result"=>15, "innings"=>14, "gd"=>1.07, "hs"=>5, "gname"=>nil)
    obj.game_id = game_id_map[50006165] if game_id_map[50006165].present?
    data = {"results"=>{"Gr."=>"group2:3-5", "Ergebnis"=>15, "Aufnahme"=>14, "GD"=>1.07, "HS"=>5, "gp_id"=>50012075}}
    obj.data = data
    created_at = Time.at(1629042225.342038)
    updated_at = Time.at(1629226521.864129)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012075] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012075] = id
  end
end
created_at = Time.at(1629042225.351764)
updated_at = Time.at(1629042225.351764)
obj_was = GameParticipation.where("id"=>50012076, "game_id"=>50006166, "player_id"=>262, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006166, "player_id"=>262, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006166, "player_id"=>262, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006166] if game_id_map[50006166].present?
    created_at = Time.at(1629042225.351764)
    updated_at = Time.at(1629042225.351764)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012076] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012076] = id
  end
end
created_at = Time.at(1629042225.3576498)
updated_at = Time.at(1629042225.3576498)
obj_was = GameParticipation.where("id"=>50012077, "game_id"=>50006166, "player_id"=>256, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006166, "player_id"=>256, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006166, "player_id"=>256, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006166] if game_id_map[50006166].present?
    created_at = Time.at(1629042225.3576498)
    updated_at = Time.at(1629042225.3576498)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012077] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012077] = id
  end
end
created_at = Time.at(1629042225.371424)
updated_at = Time.at(1629042225.371424)
obj_was = GameParticipation.where("id"=>50012078, "game_id"=>50006167, "player_id"=>262, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006167, "player_id"=>262, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006167, "player_id"=>262, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006167] if game_id_map[50006167].present?
    created_at = Time.at(1629042225.371424)
    updated_at = Time.at(1629042225.371424)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012078] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012078] = id
  end
end
created_at = Time.at(1629042225.374757)
updated_at = Time.at(1629042225.374757)
obj_was = GameParticipation.where("id"=>50012079, "game_id"=>50006167, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006167, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006167, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006167] if game_id_map[50006167].present?
    created_at = Time.at(1629042225.374757)
    updated_at = Time.at(1629042225.374757)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012079] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012079] = id
  end
end
created_at = Time.at(1629042225.389164)
updated_at = Time.at(1629226333.5311282)
obj_was = GameParticipation.where("id"=>50012080, "game_id"=>50006168, "player_id"=>262, "role"=>"playera", "points"=>0, "result"=>23, "innings"=>10, "gd"=>2.3, "hs"=>6, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006168, "player_id"=>262, "role"=>"playera", "points"=>0, "result"=>23, "innings"=>10, "gd"=>2.3, "hs"=>6, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006168, "player_id"=>262, "role"=>"playera", "points"=>0, "result"=>23, "innings"=>10, "gd"=>2.3, "hs"=>6, "gname"=>nil)
    obj.game_id = game_id_map[50006168] if game_id_map[50006168].present?
    data = {"results"=>{"Gr."=>"group2:3-8", "Ergebnis"=>23, "Aufnahme"=>10, "GD"=>2.3, "HS"=>6, "gp_id"=>50012080}}
    obj.data = data
    created_at = Time.at(1629042225.389164)
    updated_at = Time.at(1629226333.5311282)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012080] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012080] = id
  end
end
created_at = Time.at(1629042225.394629)
updated_at = Time.at(1629226333.621129)
obj_was = GameParticipation.where("id"=>50012081, "game_id"=>50006168, "player_id"=>260, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>10, "gd"=>3.2, "hs"=>9, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006168, "player_id"=>260, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>10, "gd"=>3.2, "hs"=>9, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006168, "player_id"=>260, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>10, "gd"=>3.2, "hs"=>9, "gname"=>nil)
    obj.game_id = game_id_map[50006168] if game_id_map[50006168].present?
    data = {"results"=>{"Gr."=>"group2:3-8", "Ergebnis"=>32, "Aufnahme"=>10, "GD"=>3.2, "HS"=>9, "gp_id"=>50012081}}
    obj.data = data
    created_at = Time.at(1629042225.394629)
    updated_at = Time.at(1629226333.621129)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012081] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012081] = id
  end
end
created_at = Time.at(1629042225.4058821)
updated_at = Time.at(1629225746.1387022)
obj_was = GameParticipation.where("id"=>50012082, "game_id"=>50006169, "player_id"=>252, "role"=>"playera", "points"=>0, "result"=>9, "innings"=>6, "gd"=>1.5, "hs"=>3, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006169, "player_id"=>252, "role"=>"playera", "points"=>0, "result"=>9, "innings"=>6, "gd"=>1.5, "hs"=>3, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006169, "player_id"=>252, "role"=>"playera", "points"=>0, "result"=>9, "innings"=>6, "gd"=>1.5, "hs"=>3, "gname"=>nil)
    obj.game_id = game_id_map[50006169] if game_id_map[50006169].present?
    data = {"results"=>{"Gr."=>"group2:4-5", "Ergebnis"=>9, "Aufnahme"=>6, "GD"=>1.5, "HS"=>3, "gp_id"=>50012082}}
    obj.data = data
    created_at = Time.at(1629042225.4058821)
    updated_at = Time.at(1629225746.1387022)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012082] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012082] = id
  end
end
created_at = Time.at(1629042225.40946)
updated_at = Time.at(1629225746.239666)
obj_was = GameParticipation.where("id"=>50012083, "game_id"=>50006169, "player_id"=>50000001, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>6, "gd"=>2.67, "hs"=>10, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006169, "player_id"=>50000001, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>6, "gd"=>2.67, "hs"=>10, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006169, "player_id"=>50000001, "role"=>"playerb", "points"=>2, "result"=>16, "innings"=>6, "gd"=>2.67, "hs"=>10, "gname"=>nil)
    obj.game_id = game_id_map[50006169] if game_id_map[50006169].present?
    data = {"results"=>{"Gr."=>"group2:4-5", "Ergebnis"=>16, "Aufnahme"=>6, "GD"=>2.67, "HS"=>10, "gp_id"=>50012083}}
    obj.data = data
    created_at = Time.at(1629042225.40946)
    updated_at = Time.at(1629225746.239666)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012083] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012083] = id
  end
end
created_at = Time.at(1629042225.41892)
updated_at = Time.at(1629042225.41892)
obj_was = GameParticipation.where("id"=>50012084, "game_id"=>50006170, "player_id"=>252, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006170, "player_id"=>252, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006170, "player_id"=>252, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006170] if game_id_map[50006170].present?
    created_at = Time.at(1629042225.41892)
    updated_at = Time.at(1629042225.41892)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012084] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012084] = id
  end
end
created_at = Time.at(1629042225.422921)
updated_at = Time.at(1629042225.422921)
obj_was = GameParticipation.where("id"=>50012085, "game_id"=>50006170, "player_id"=>256, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006170, "player_id"=>256, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006170, "player_id"=>256, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006170] if game_id_map[50006170].present?
    created_at = Time.at(1629042225.422921)
    updated_at = Time.at(1629042225.422921)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012085] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012085] = id
  end
end
created_at = Time.at(1629042225.4300458)
updated_at = Time.at(1629042225.4300458)
obj_was = GameParticipation.where("id"=>50012086, "game_id"=>50006171, "player_id"=>252, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006171, "player_id"=>252, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006171, "player_id"=>252, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006171] if game_id_map[50006171].present?
    created_at = Time.at(1629042225.4300458)
    updated_at = Time.at(1629042225.4300458)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012086] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012086] = id
  end
end
created_at = Time.at(1629042225.435898)
updated_at = Time.at(1629042225.435898)
obj_was = GameParticipation.where("id"=>50012087, "game_id"=>50006171, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006171, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006171, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006171] if game_id_map[50006171].present?
    created_at = Time.at(1629042225.435898)
    updated_at = Time.at(1629042225.435898)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012087] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012087] = id
  end
end
created_at = Time.at(1629042225.447477)
updated_at = Time.at(1629225973.373816)
obj_was = GameParticipation.where("id"=>50012088, "game_id"=>50006172, "player_id"=>252, "role"=>"playera", "points"=>2, "result"=>32, "innings"=>7, "gd"=>4.57, "hs"=>9, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006172, "player_id"=>252, "role"=>"playera", "points"=>2, "result"=>32, "innings"=>7, "gd"=>4.57, "hs"=>9, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006172, "player_id"=>252, "role"=>"playera", "points"=>2, "result"=>32, "innings"=>7, "gd"=>4.57, "hs"=>9, "gname"=>nil)
    obj.game_id = game_id_map[50006172] if game_id_map[50006172].present?
    data = {"results"=>{"Gr."=>"group2:4-8", "Ergebnis"=>32, "Aufnahme"=>7, "GD"=>4.57, "HS"=>9, "gp_id"=>50012088}}
    obj.data = data
    created_at = Time.at(1629042225.447477)
    updated_at = Time.at(1629225973.373816)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012088] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012088] = id
  end
end
created_at = Time.at(1629042225.4521458)
updated_at = Time.at(1629225973.473034)
obj_was = GameParticipation.where("id"=>50012089, "game_id"=>50006172, "player_id"=>260, "role"=>"playerb", "points"=>0, "result"=>4, "innings"=>7, "gd"=>0.57, "hs"=>3, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006172, "player_id"=>260, "role"=>"playerb", "points"=>0, "result"=>4, "innings"=>7, "gd"=>0.57, "hs"=>3, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006172, "player_id"=>260, "role"=>"playerb", "points"=>0, "result"=>4, "innings"=>7, "gd"=>0.57, "hs"=>3, "gname"=>nil)
    obj.game_id = game_id_map[50006172] if game_id_map[50006172].present?
    data = {"results"=>{"Gr."=>"group2:4-8", "Ergebnis"=>4, "Aufnahme"=>7, "GD"=>0.57, "HS"=>3, "gp_id"=>50012089}}
    obj.data = data
    created_at = Time.at(1629042225.4521458)
    updated_at = Time.at(1629225973.473034)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012089] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012089] = id
  end
end
created_at = Time.at(1629042225.4634612)
updated_at = Time.at(1629042225.4634612)
obj_was = GameParticipation.where("id"=>50012090, "game_id"=>50006173, "player_id"=>50000001, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006173, "player_id"=>50000001, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006173, "player_id"=>50000001, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006173] if game_id_map[50006173].present?
    created_at = Time.at(1629042225.4634612)
    updated_at = Time.at(1629042225.4634612)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012090] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012090] = id
  end
end
created_at = Time.at(1629042225.467961)
updated_at = Time.at(1629042225.467961)
obj_was = GameParticipation.where("id"=>50012091, "game_id"=>50006173, "player_id"=>256, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006173, "player_id"=>256, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006173, "player_id"=>256, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006173] if game_id_map[50006173].present?
    created_at = Time.at(1629042225.467961)
    updated_at = Time.at(1629042225.467961)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012091] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012091] = id
  end
end
created_at = Time.at(1629042225.4759161)
updated_at = Time.at(1629042225.4759161)
obj_was = GameParticipation.where("id"=>50012092, "game_id"=>50006174, "player_id"=>50000001, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006174, "player_id"=>50000001, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006174, "player_id"=>50000001, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006174] if game_id_map[50006174].present?
    created_at = Time.at(1629042225.4759161)
    updated_at = Time.at(1629042225.4759161)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012092] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012092] = id
  end
end
created_at = Time.at(1629042225.479777)
updated_at = Time.at(1629042225.479777)
obj_was = GameParticipation.where("id"=>50012093, "game_id"=>50006174, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006174, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006174, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006174] if game_id_map[50006174].present?
    created_at = Time.at(1629042225.479777)
    updated_at = Time.at(1629042225.479777)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012093] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012093] = id
  end
end
created_at = Time.at(1629042225.492874)
updated_at = Time.at(1629226680.930004)
obj_was = GameParticipation.where("id"=>50012094, "game_id"=>50006175, "player_id"=>50000001, "role"=>"playera", "points"=>0, "result"=>12, "innings"=>16, "gd"=>0.75, "hs"=>4, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006175, "player_id"=>50000001, "role"=>"playera", "points"=>0, "result"=>12, "innings"=>16, "gd"=>0.75, "hs"=>4, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006175, "player_id"=>50000001, "role"=>"playera", "points"=>0, "result"=>12, "innings"=>16, "gd"=>0.75, "hs"=>4, "gname"=>nil)
    obj.game_id = game_id_map[50006175] if game_id_map[50006175].present?
    data = {"results"=>{"Gr."=>"group2:5-8", "Ergebnis"=>12, "Aufnahme"=>16, "GD"=>0.75, "HS"=>4, "gp_id"=>50012094}}
    obj.data = data
    created_at = Time.at(1629042225.492874)
    updated_at = Time.at(1629226680.930004)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012094] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012094] = id
  end
end
created_at = Time.at(1629042225.4989948)
updated_at = Time.at(1629226681.021143)
obj_was = GameParticipation.where("id"=>50012095, "game_id"=>50006175, "player_id"=>260, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>16, "gd"=>2.0, "hs"=>10, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006175, "player_id"=>260, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>16, "gd"=>2.0, "hs"=>10, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006175, "player_id"=>260, "role"=>"playerb", "points"=>2, "result"=>32, "innings"=>16, "gd"=>2.0, "hs"=>10, "gname"=>nil)
    obj.game_id = game_id_map[50006175] if game_id_map[50006175].present?
    data = {"results"=>{"Gr."=>"group2:5-8", "Ergebnis"=>32, "Aufnahme"=>16, "GD"=>2.0, "HS"=>10, "gp_id"=>50012095}}
    obj.data = data
    created_at = Time.at(1629042225.4989948)
    updated_at = Time.at(1629226681.021143)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012095] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012095] = id
  end
end
created_at = Time.at(1629042225.511748)
updated_at = Time.at(1629042225.511748)
obj_was = GameParticipation.where("id"=>50012096, "game_id"=>50006176, "player_id"=>256, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006176, "player_id"=>256, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006176, "player_id"=>256, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006176] if game_id_map[50006176].present?
    created_at = Time.at(1629042225.511748)
    updated_at = Time.at(1629042225.511748)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012096] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012096] = id
  end
end
created_at = Time.at(1629042225.517953)
updated_at = Time.at(1629042225.517953)
obj_was = GameParticipation.where("id"=>50012097, "game_id"=>50006176, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006176, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006176, "player_id"=>251, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006176] if game_id_map[50006176].present?
    created_at = Time.at(1629042225.517953)
    updated_at = Time.at(1629042225.517953)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012097] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012097] = id
  end
end
created_at = Time.at(1629042225.531161)
updated_at = Time.at(1629042225.531161)
obj_was = GameParticipation.where("id"=>50012098, "game_id"=>50006177, "player_id"=>256, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006177, "player_id"=>256, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006177, "player_id"=>256, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006177] if game_id_map[50006177].present?
    created_at = Time.at(1629042225.531161)
    updated_at = Time.at(1629042225.531161)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012098] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012098] = id
  end
end
created_at = Time.at(1629042225.538343)
updated_at = Time.at(1629042225.538343)
obj_was = GameParticipation.where("id"=>50012099, "game_id"=>50006177, "player_id"=>260, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006177, "player_id"=>260, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006177, "player_id"=>260, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006177] if game_id_map[50006177].present?
    created_at = Time.at(1629042225.538343)
    updated_at = Time.at(1629042225.538343)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012099] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012099] = id
  end
end
created_at = Time.at(1629042225.547245)
updated_at = Time.at(1629042225.547245)
obj_was = GameParticipation.where("id"=>50012100, "game_id"=>50006178, "player_id"=>251, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006178, "player_id"=>251, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006178, "player_id"=>251, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006178] if game_id_map[50006178].present?
    created_at = Time.at(1629042225.547245)
    updated_at = Time.at(1629042225.547245)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012100] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012100] = id
  end
end
created_at = Time.at(1629042225.550281)
updated_at = Time.at(1629042225.550281)
obj_was = GameParticipation.where("id"=>50012101, "game_id"=>50006178, "player_id"=>260, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006178, "player_id"=>260, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006178, "player_id"=>260, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006178] if game_id_map[50006178].present?
    created_at = Time.at(1629042225.550281)
    updated_at = Time.at(1629042225.550281)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012101] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012101] = id
  end
end
created_at = Time.at(1629225094.813185)
updated_at = Time.at(1629225094.813185)
obj_was = GameParticipation.where("id"=>50012102, "game_id"=>50006179, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006179, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006179, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006179] if game_id_map[50006179].present?
    created_at = Time.at(1629225094.813185)
    updated_at = Time.at(1629225094.813185)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012102] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012102] = id
  end
end
created_at = Time.at(1629225094.828465)
updated_at = Time.at(1629225094.828465)
obj_was = GameParticipation.where("id"=>50012103, "game_id"=>50006179, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006179, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006179, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006179] if game_id_map[50006179].present?
    created_at = Time.at(1629225094.828465)
    updated_at = Time.at(1629225094.828465)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012103] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012103] = id
  end
end
created_at = Time.at(1629666567.412548)
updated_at = Time.at(1629666567.412548)
obj_was = GameParticipation.where("id"=>50012146, "game_id"=>50006201, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006201, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006201, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006201] if game_id_map[50006201].present?
    created_at = Time.at(1629666567.412548)
    updated_at = Time.at(1629666567.412548)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012146] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012146] = id
  end
end
created_at = Time.at(1629666567.419276)
updated_at = Time.at(1629666567.419276)
obj_was = GameParticipation.where("id"=>50012147, "game_id"=>50006201, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006201, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006201, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006201] if game_id_map[50006201].present?
    created_at = Time.at(1629666567.419276)
    updated_at = Time.at(1629666567.419276)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012147] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012147] = id
  end
end
created_at = Time.at(1629666608.684205)
updated_at = Time.at(1629666608.684205)
obj_was = GameParticipation.where("id"=>50012148, "game_id"=>50006202, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006202, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006202, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006202] if game_id_map[50006202].present?
    created_at = Time.at(1629666608.684205)
    updated_at = Time.at(1629666608.684205)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012148] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012148] = id
  end
end
created_at = Time.at(1629666608.695265)
updated_at = Time.at(1629666608.695265)
obj_was = GameParticipation.where("id"=>50012149, "game_id"=>50006202, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006202, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006202, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006202] if game_id_map[50006202].present?
    created_at = Time.at(1629666608.695265)
    updated_at = Time.at(1629666608.695265)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012149] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012149] = id
  end
end
created_at = Time.at(1629666894.8293939)
updated_at = Time.at(1629666894.8293939)
obj_was = GameParticipation.where("id"=>50012152, "game_id"=>50006203, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006203, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006203, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006203] if game_id_map[50006203].present?
    created_at = Time.at(1629666894.8293939)
    updated_at = Time.at(1629666894.8293939)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012152] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012152] = id
  end
end
created_at = Time.at(1629666894.834372)
updated_at = Time.at(1629666894.834372)
obj_was = GameParticipation.where("id"=>50012153, "game_id"=>50006203, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006203, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006203, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006203] if game_id_map[50006203].present?
    created_at = Time.at(1629666894.834372)
    updated_at = Time.at(1629666894.834372)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012153] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012153] = id
  end
end
created_at = Time.at(1629675848.218715)
updated_at = Time.at(1629675848.218715)
obj_was = GameParticipation.where("id"=>50012154, "game_id"=>50006204, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006204, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006204, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006204] if game_id_map[50006204].present?
    created_at = Time.at(1629675848.218715)
    updated_at = Time.at(1629675848.218715)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012154] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012154] = id
  end
end
created_at = Time.at(1629675848.230913)
updated_at = Time.at(1629675848.230913)
obj_was = GameParticipation.where("id"=>50012155, "game_id"=>50006204, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006204, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006204, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006204] if game_id_map[50006204].present?
    created_at = Time.at(1629675848.230913)
    updated_at = Time.at(1629675848.230913)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012155] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012155] = id
  end
end
created_at = Time.at(1630055301.6490052)
updated_at = Time.at(1630055301.6490052)
obj_was = GameParticipation.where("id"=>50012168, "game_id"=>50006208, "player_id"=>254, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006208, "player_id"=>254, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006208, "player_id"=>254, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006208] if game_id_map[50006208].present?
    created_at = Time.at(1630055301.6490052)
    updated_at = Time.at(1630055301.6490052)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012168] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012168] = id
  end
end
created_at = Time.at(1630055301.655169)
updated_at = Time.at(1630055301.655169)
obj_was = GameParticipation.where("id"=>50012169, "game_id"=>50006208, "player_id"=>247, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006208, "player_id"=>247, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006208, "player_id"=>247, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006208] if game_id_map[50006208].present?
    created_at = Time.at(1630055301.655169)
    updated_at = Time.at(1630055301.655169)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012169] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012169] = id
  end
end
created_at = Time.at(1630055353.0269032)
updated_at = Time.at(1630055353.0269032)
obj_was = GameParticipation.where("id"=>50012170, "game_id"=>50006209, "player_id"=>247, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006209, "player_id"=>247, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006209, "player_id"=>247, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006209] if game_id_map[50006209].present?
    created_at = Time.at(1630055353.0269032)
    updated_at = Time.at(1630055353.0269032)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012170] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012170] = id
  end
end
created_at = Time.at(1630055353.0548868)
updated_at = Time.at(1630055353.0548868)
obj_was = GameParticipation.where("id"=>50012171, "game_id"=>50006209, "player_id"=>254, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006209, "player_id"=>254, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006209, "player_id"=>254, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006209] if game_id_map[50006209].present?
    created_at = Time.at(1630055353.0548868)
    updated_at = Time.at(1630055353.0548868)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012171] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012171] = id
  end
end
created_at = Time.at(1630055429.988708)
updated_at = Time.at(1630055429.988708)
obj_was = GameParticipation.where("id"=>50012172, "game_id"=>50006210, "player_id"=>254, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006210, "player_id"=>254, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006210, "player_id"=>254, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006210] if game_id_map[50006210].present?
    created_at = Time.at(1630055429.988708)
    updated_at = Time.at(1630055429.988708)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012172] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012172] = id
  end
end
created_at = Time.at(1630055429.9939358)
updated_at = Time.at(1630055429.9939358)
obj_was = GameParticipation.where("id"=>50012173, "game_id"=>50006210, "player_id"=>247, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006210, "player_id"=>247, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006210, "player_id"=>247, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006210] if game_id_map[50006210].present?
    created_at = Time.at(1630055429.9939358)
    updated_at = Time.at(1630055429.9939358)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012173] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012173] = id
  end
end
created_at = Time.at(1630055454.588653)
updated_at = Time.at(1630055454.588653)
obj_was = GameParticipation.where("id"=>50012174, "game_id"=>50006211, "player_id"=>247, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006211, "player_id"=>247, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006211, "player_id"=>247, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006211] if game_id_map[50006211].present?
    created_at = Time.at(1630055454.588653)
    updated_at = Time.at(1630055454.588653)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012174] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012174] = id
  end
end
created_at = Time.at(1630055454.5933719)
updated_at = Time.at(1630055454.5933719)
obj_was = GameParticipation.where("id"=>50012175, "game_id"=>50006211, "player_id"=>254, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006211, "player_id"=>254, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006211, "player_id"=>254, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006211] if game_id_map[50006211].present?
    created_at = Time.at(1630055454.5933719)
    updated_at = Time.at(1630055454.5933719)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012175] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012175] = id
  end
end
created_at = Time.at(1630236541.534791)
updated_at = Time.at(1630236541.534791)
obj_was = GameParticipation.where("id"=>50012206, "game_id"=>50006219, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006219, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006219, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006219] if game_id_map[50006219].present?
    created_at = Time.at(1630236541.534791)
    updated_at = Time.at(1630236541.534791)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012206] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012206] = id
  end
end
created_at = Time.at(1630236541.5410812)
updated_at = Time.at(1630236541.5410812)
obj_was = GameParticipation.where("id"=>50012207, "game_id"=>50006219, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006219, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006219, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006219] if game_id_map[50006219].present?
    created_at = Time.at(1630236541.5410812)
    updated_at = Time.at(1630236541.5410812)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012207] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012207] = id
  end
end
created_at = Time.at(1630248198.430718)
updated_at = Time.at(1630248198.430718)
obj_was = GameParticipation.where("id"=>50012208, "game_id"=>50006220, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006220, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006220, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006220] if game_id_map[50006220].present?
    created_at = Time.at(1630248198.430718)
    updated_at = Time.at(1630248198.430718)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012208] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012208] = id
  end
end
created_at = Time.at(1630248198.441321)
updated_at = Time.at(1630248198.441321)
obj_was = GameParticipation.where("id"=>50012209, "game_id"=>50006220, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006220, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006220, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006220] if game_id_map[50006220].present?
    created_at = Time.at(1630248198.441321)
    updated_at = Time.at(1630248198.441321)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012209] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012209] = id
  end
end
created_at = Time.at(1630490963.927347)
updated_at = Time.at(1630490963.927347)
obj_was = GameParticipation.where("id"=>50012234, "game_id"=>50006227, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006227, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006227, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006227] if game_id_map[50006227].present?
    created_at = Time.at(1630490963.927347)
    updated_at = Time.at(1630490963.927347)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012234] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012234] = id
  end
end
created_at = Time.at(1630490963.933098)
updated_at = Time.at(1630490963.933098)
obj_was = GameParticipation.where("id"=>50012235, "game_id"=>50006227, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006227, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006227, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006227] if game_id_map[50006227].present?
    created_at = Time.at(1630490963.933098)
    updated_at = Time.at(1630490963.933098)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012235] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012235] = id
  end
end
created_at = Time.at(1630491602.251647)
updated_at = Time.at(1630491602.251647)
obj_was = GameParticipation.where("id"=>50012240, "game_id"=>50006229, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006229, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006229, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006229] if game_id_map[50006229].present?
    created_at = Time.at(1630491602.251647)
    updated_at = Time.at(1630491602.251647)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012240] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012240] = id
  end
end
created_at = Time.at(1630491602.256402)
updated_at = Time.at(1630491602.256402)
obj_was = GameParticipation.where("id"=>50012241, "game_id"=>50006229, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006229, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006229, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006229] if game_id_map[50006229].present?
    created_at = Time.at(1630491602.256402)
    updated_at = Time.at(1630491602.256402)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012241] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012241] = id
  end
end
created_at = Time.at(1630491813.717803)
updated_at = Time.at(1630491813.717803)
obj_was = GameParticipation.where("id"=>50012242, "game_id"=>50006230, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006230, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006230, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006230] if game_id_map[50006230].present?
    created_at = Time.at(1630491813.717803)
    updated_at = Time.at(1630491813.717803)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012242] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012242] = id
  end
end
created_at = Time.at(1630491813.73254)
updated_at = Time.at(1630491813.73254)
obj_was = GameParticipation.where("id"=>50012243, "game_id"=>50006230, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006230, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006230, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006230] if game_id_map[50006230].present?
    created_at = Time.at(1630491813.73254)
    updated_at = Time.at(1630491813.73254)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012243] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012243] = id
  end
end
created_at = Time.at(1630492877.0369978)
updated_at = Time.at(1630492877.0369978)
obj_was = GameParticipation.where("id"=>50012246, "game_id"=>50006231, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006231, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006231, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006231] if game_id_map[50006231].present?
    created_at = Time.at(1630492877.0369978)
    updated_at = Time.at(1630492877.0369978)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012246] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012246] = id
  end
end
created_at = Time.at(1630492877.048428)
updated_at = Time.at(1630492877.048428)
obj_was = GameParticipation.where("id"=>50012247, "game_id"=>50006231, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006231, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006231, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006231] if game_id_map[50006231].present?
    created_at = Time.at(1630492877.048428)
    updated_at = Time.at(1630492877.048428)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012247] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012247] = id
  end
end
created_at = Time.at(1630493294.824227)
updated_at = Time.at(1630493294.824227)
obj_was = GameParticipation.where("id"=>50012250, "game_id"=>50006232, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006232, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006232, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006232] if game_id_map[50006232].present?
    created_at = Time.at(1630493294.824227)
    updated_at = Time.at(1630493294.824227)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012250] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012250] = id
  end
end
created_at = Time.at(1630493294.835131)
updated_at = Time.at(1630493294.835131)
obj_was = GameParticipation.where("id"=>50012251, "game_id"=>50006232, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006232, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006232, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006232] if game_id_map[50006232].present?
    created_at = Time.at(1630493294.835131)
    updated_at = Time.at(1630493294.835131)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012251] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012251] = id
  end
end
created_at = Time.at(1630493340.437043)
updated_at = Time.at(1630493340.437043)
obj_was = GameParticipation.where("id"=>50012252, "game_id"=>50006233, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006233, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006233, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006233] if game_id_map[50006233].present?
    created_at = Time.at(1630493340.437043)
    updated_at = Time.at(1630493340.437043)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012252] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012252] = id
  end
end
created_at = Time.at(1630493340.4465091)
updated_at = Time.at(1630493340.4465091)
obj_was = GameParticipation.where("id"=>50012253, "game_id"=>50006233, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006233, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006233, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006233] if game_id_map[50006233].present?
    created_at = Time.at(1630493340.4465091)
    updated_at = Time.at(1630493340.4465091)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012253] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012253] = id
  end
end
created_at = Time.at(1630493784.074545)
updated_at = Time.at(1630493784.074545)
obj_was = GameParticipation.where("id"=>50012254, "game_id"=>50006234, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006234, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006234, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006234] if game_id_map[50006234].present?
    created_at = Time.at(1630493784.074545)
    updated_at = Time.at(1630493784.074545)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012254] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012254] = id
  end
end
created_at = Time.at(1630493784.0812302)
updated_at = Time.at(1630493784.0812302)
obj_was = GameParticipation.where("id"=>50012255, "game_id"=>50006234, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006234, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006234, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006234] if game_id_map[50006234].present?
    created_at = Time.at(1630493784.0812302)
    updated_at = Time.at(1630493784.0812302)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012255] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012255] = id
  end
end
created_at = Time.at(1630691412.181631)
updated_at = Time.at(1630691412.181631)
obj_was = GameParticipation.where("id"=>50012456, "game_id"=>50006335, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006335, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006335, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006335] if game_id_map[50006335].present?
    created_at = Time.at(1630691412.181631)
    updated_at = Time.at(1630691412.181631)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012456] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012456] = id
  end
end
created_at = Time.at(1630691412.186806)
updated_at = Time.at(1630691412.186806)
obj_was = GameParticipation.where("id"=>50012457, "game_id"=>50006335, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006335, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006335, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006335] if game_id_map[50006335].present?
    created_at = Time.at(1630691412.186806)
    updated_at = Time.at(1630691412.186806)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012457] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012457] = id
  end
end
created_at = Time.at(1630695256.103631)
updated_at = Time.at(1630695256.103631)
obj_was = GameParticipation.where("id"=>50012470, "game_id"=>50006338, "player_id"=>295, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006338, "player_id"=>295, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006338, "player_id"=>295, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006338] if game_id_map[50006338].present?
    created_at = Time.at(1630695256.103631)
    updated_at = Time.at(1630695256.103631)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012470] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012470] = id
  end
end
created_at = Time.at(1630695256.111306)
updated_at = Time.at(1630695256.111306)
obj_was = GameParticipation.where("id"=>50012471, "game_id"=>50006338, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006338, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006338, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006338] if game_id_map[50006338].present?
    created_at = Time.at(1630695256.111306)
    updated_at = Time.at(1630695256.111306)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012471] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012471] = id
  end
end
created_at = Time.at(1630705264.552898)
updated_at = Time.at(1630705264.552898)
obj_was = GameParticipation.where("id"=>50012486, "game_id"=>50006342, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006342, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006342, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006342] if game_id_map[50006342].present?
    created_at = Time.at(1630705264.552898)
    updated_at = Time.at(1630705264.552898)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012486] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012486] = id
  end
end
created_at = Time.at(1630705264.559684)
updated_at = Time.at(1630705264.559684)
obj_was = GameParticipation.where("id"=>50012487, "game_id"=>50006342, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006342, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006342, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006342] if game_id_map[50006342].present?
    created_at = Time.at(1630705264.559684)
    updated_at = Time.at(1630705264.559684)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012487] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012487] = id
  end
end
created_at = Time.at(1630987469.1618218)
updated_at = Time.at(1630987469.1618218)
obj_was = GameParticipation.where("id"=>50012520, "game_id"=>50006358, "player_id"=>250, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006358, "player_id"=>250, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006358, "player_id"=>250, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006358] if game_id_map[50006358].present?
    created_at = Time.at(1630987469.1618218)
    updated_at = Time.at(1630987469.1618218)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012520] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012520] = id
  end
end
created_at = Time.at(1630987469.1677551)
updated_at = Time.at(1630987469.1677551)
obj_was = GameParticipation.where("id"=>50012521, "game_id"=>50006358, "player_id"=>265, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006358, "player_id"=>265, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006358, "player_id"=>265, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006358] if game_id_map[50006358].present?
    created_at = Time.at(1630987469.1677551)
    updated_at = Time.at(1630987469.1677551)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012521] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012521] = id
  end
end
created_at = Time.at(1631195983.133853)
updated_at = Time.at(1631195983.133853)
obj_was = GameParticipation.where("id"=>50012552, "game_id"=>50006374, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006374, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006374, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006374] if game_id_map[50006374].present?
    created_at = Time.at(1631195983.133853)
    updated_at = Time.at(1631195983.133853)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012552] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012552] = id
  end
end
created_at = Time.at(1631195983.15127)
updated_at = Time.at(1631195983.15127)
obj_was = GameParticipation.where("id"=>50012553, "game_id"=>50006374, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006374, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006374, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006374] if game_id_map[50006374].present?
    created_at = Time.at(1631195983.15127)
    updated_at = Time.at(1631195983.15127)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012553] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012553] = id
  end
end
created_at = Time.at(1631201181.541203)
updated_at = Time.at(1631201301.75646)
obj_was = GameParticipation.where("id"=>50012616, "game_id"=>50006405, "player_id"=>249, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006405, "player_id"=>249, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006405, "player_id"=>249, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006405] if game_id_map[50006405].present?
    created_at = Time.at(1631201181.541203)
    updated_at = Time.at(1631201301.75646)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012616] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012616] = id
  end
end
created_at = Time.at(1631201181.563922)
updated_at = Time.at(1631201301.789494)
obj_was = GameParticipation.where("id"=>50012617, "game_id"=>50006405, "player_id"=>266, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006405, "player_id"=>266, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006405, "player_id"=>266, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006405] if game_id_map[50006405].present?
    created_at = Time.at(1631201181.563922)
    updated_at = Time.at(1631201301.789494)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012617] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012617] = id
  end
end
created_at = Time.at(1631205683.795437)
updated_at = Time.at(1631205956.911843)
obj_was = GameParticipation.where("id"=>50012636, "game_id"=>50006411, "player_id"=>50000002, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006411, "player_id"=>50000002, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006411, "player_id"=>50000002, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006411] if game_id_map[50006411].present?
    created_at = Time.at(1631205683.795437)
    updated_at = Time.at(1631205956.911843)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012636] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012636] = id
  end
end
created_at = Time.at(1631205683.8184)
updated_at = Time.at(1631205956.737591)
obj_was = GameParticipation.where("id"=>50012637, "game_id"=>50006411, "player_id"=>266, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006411, "player_id"=>266, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006411, "player_id"=>266, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006411] if game_id_map[50006411].present?
    created_at = Time.at(1631205683.8184)
    updated_at = Time.at(1631205956.737591)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012637] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012637] = id
  end
end
created_at = Time.at(1631214525.2817159)
updated_at = Time.at(1631214525.2817159)
obj_was = GameParticipation.where("id"=>50012658, "game_id"=>50006418, "player_id"=>254, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006418, "player_id"=>254, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006418, "player_id"=>254, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006418] if game_id_map[50006418].present?
    created_at = Time.at(1631214525.2817159)
    updated_at = Time.at(1631214525.2817159)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012658] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012658] = id
  end
end
created_at = Time.at(1631214525.2994182)
updated_at = Time.at(1631214525.2994182)
obj_was = GameParticipation.where("id"=>50012659, "game_id"=>50006418, "player_id"=>247, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006418, "player_id"=>247, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006418, "player_id"=>247, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006418] if game_id_map[50006418].present?
    created_at = Time.at(1631214525.2994182)
    updated_at = Time.at(1631214525.2994182)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012659] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012659] = id
  end
end
created_at = Time.at(1631216520.7471528)
updated_at = Time.at(1631216520.7471528)
obj_was = GameParticipation.where("id"=>50012664, "game_id"=>50006420, "player_id"=>247, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006420, "player_id"=>247, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006420, "player_id"=>247, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006420] if game_id_map[50006420].present?
    created_at = Time.at(1631216520.7471528)
    updated_at = Time.at(1631216520.7471528)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012664] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012664] = id
  end
end
created_at = Time.at(1631216520.776174)
updated_at = Time.at(1631216520.776174)
obj_was = GameParticipation.where("id"=>50012665, "game_id"=>50006420, "player_id"=>254, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006420, "player_id"=>254, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006420, "player_id"=>254, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006420] if game_id_map[50006420].present?
    created_at = Time.at(1631216520.776174)
    updated_at = Time.at(1631216520.776174)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012665] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012665] = id
  end
end
created_at = Time.at(1631218730.350712)
updated_at = Time.at(1631218730.350712)
obj_was = GameParticipation.where("id"=>50012666, "game_id"=>50006421, "player_id"=>254, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006421, "player_id"=>254, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006421, "player_id"=>254, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006421] if game_id_map[50006421].present?
    created_at = Time.at(1631218730.350712)
    updated_at = Time.at(1631218730.350712)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012666] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012666] = id
  end
end
created_at = Time.at(1631218730.372617)
updated_at = Time.at(1631218730.372617)
obj_was = GameParticipation.where("id"=>50012667, "game_id"=>50006421, "player_id"=>247, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006421, "player_id"=>247, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006421, "player_id"=>247, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006421] if game_id_map[50006421].present?
    created_at = Time.at(1631218730.372617)
    updated_at = Time.at(1631218730.372617)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012667] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012667] = id
  end
end
created_at = Time.at(1631218959.659463)
updated_at = Time.at(1631218959.659463)
obj_was = GameParticipation.where("id"=>50012668, "game_id"=>50006422, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006422, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006422, "player_id"=>nil, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006422] if game_id_map[50006422].present?
    created_at = Time.at(1631218959.659463)
    updated_at = Time.at(1631218959.659463)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012668] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012668] = id
  end
end
created_at = Time.at(1631218959.672022)
updated_at = Time.at(1631218959.672022)
obj_was = GameParticipation.where("id"=>50012669, "game_id"=>50006422, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006422, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006422, "player_id"=>nil, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006422] if game_id_map[50006422].present?
    created_at = Time.at(1631218959.672022)
    updated_at = Time.at(1631218959.672022)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012669] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012669] = id
  end
end
created_at = Time.at(1631220856.743826)
updated_at = Time.at(1631220856.743826)
obj_was = GameParticipation.where("id"=>50012670, "game_id"=>50006423, "player_id"=>247, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006423, "player_id"=>247, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006423, "player_id"=>247, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006423] if game_id_map[50006423].present?
    created_at = Time.at(1631220856.743826)
    updated_at = Time.at(1631220856.743826)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012670] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012670] = id
  end
end
created_at = Time.at(1631220856.761881)
updated_at = Time.at(1631220856.761881)
obj_was = GameParticipation.where("id"=>50012671, "game_id"=>50006423, "player_id"=>254, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006423, "player_id"=>254, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006423, "player_id"=>254, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006423] if game_id_map[50006423].present?
    created_at = Time.at(1631220856.761881)
    updated_at = Time.at(1631220856.761881)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012671] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012671] = id
  end
end
created_at = Time.at(1631287790.399158)
updated_at = Time.at(1631287790.399158)
obj_was = GameParticipation.where("id"=>50012676, "game_id"=>50006425, "player_id"=>50000002, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006425, "player_id"=>50000002, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006425, "player_id"=>50000002, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006425] if game_id_map[50006425].present?
    created_at = Time.at(1631287790.399158)
    updated_at = Time.at(1631287790.399158)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012676] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012676] = id
  end
end
created_at = Time.at(1631287790.4165912)
updated_at = Time.at(1631287790.4165912)
obj_was = GameParticipation.where("id"=>50012677, "game_id"=>50006425, "player_id"=>266, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006425, "player_id"=>266, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006425, "player_id"=>266, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006425] if game_id_map[50006425].present?
    created_at = Time.at(1631287790.4165912)
    updated_at = Time.at(1631287790.4165912)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012677] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012677] = id
  end
end
created_at = Time.at(1631293644.292147)
updated_at = Time.at(1631293644.292147)
obj_was = GameParticipation.where("id"=>50012678, "game_id"=>50006426, "player_id"=>255, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006426, "player_id"=>255, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006426, "player_id"=>255, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006426] if game_id_map[50006426].present?
    created_at = Time.at(1631293644.292147)
    updated_at = Time.at(1631293644.292147)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012678] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012678] = id
  end
end
created_at = Time.at(1631293644.305092)
updated_at = Time.at(1631293644.305092)
obj_was = GameParticipation.where("id"=>50012679, "game_id"=>50006426, "player_id"=>259, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006426, "player_id"=>259, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006426, "player_id"=>259, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006426] if game_id_map[50006426].present?
    created_at = Time.at(1631293644.305092)
    updated_at = Time.at(1631293644.305092)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012679] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012679] = id
  end
end
created_at = Time.at(1631293644.329152)
updated_at = Time.at(1631372318.413144)
obj_was = GameParticipation.where("id"=>50012680, "game_id"=>50006427, "player_id"=>255, "role"=>"playera", "points"=>0, "result"=>60, "innings"=>17, "gd"=>3.53, "hs"=>23, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006427, "player_id"=>255, "role"=>"playera", "points"=>0, "result"=>60, "innings"=>17, "gd"=>3.53, "hs"=>23, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006427, "player_id"=>255, "role"=>"playera", "points"=>0, "result"=>60, "innings"=>17, "gd"=>3.53, "hs"=>23, "gname"=>nil)
    obj.game_id = game_id_map[50006427] if game_id_map[50006427].present?
    data = {"results"=>{"Gr."=>"group1:1-3", "Ergebnis"=>60, "Aufnahme"=>17, "GD"=>3.53, "HS"=>23, "gp_id"=>50012680}}
    obj.data = data
    created_at = Time.at(1631293644.329152)
    updated_at = Time.at(1631372318.413144)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012680] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012680] = id
  end
end
created_at = Time.at(1631293644.3410208)
updated_at = Time.at(1631372318.613199)
obj_was = GameParticipation.where("id"=>50012681, "game_id"=>50006427, "player_id"=>297, "role"=>"playerb", "points"=>2, "result"=>80, "innings"=>17, "gd"=>4.71, "hs"=>27, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006427, "player_id"=>297, "role"=>"playerb", "points"=>2, "result"=>80, "innings"=>17, "gd"=>4.71, "hs"=>27, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006427, "player_id"=>297, "role"=>"playerb", "points"=>2, "result"=>80, "innings"=>17, "gd"=>4.71, "hs"=>27, "gname"=>nil)
    obj.game_id = game_id_map[50006427] if game_id_map[50006427].present?
    data = {"results"=>{"Gr."=>"group1:1-3", "Ergebnis"=>80, "Aufnahme"=>17, "GD"=>4.71, "HS"=>27, "gp_id"=>50012681}}
    obj.data = data
    created_at = Time.at(1631293644.3410208)
    updated_at = Time.at(1631372318.613199)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012681] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012681] = id
  end
end
created_at = Time.at(1631293644.3653572)
updated_at = Time.at(1631365360.3830578)
obj_was = GameParticipation.where("id"=>50012682, "game_id"=>50006428, "player_id"=>255, "role"=>"playera", "points"=>2, "result"=>80, "innings"=>17, "gd"=>4.71, "hs"=>26, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006428, "player_id"=>255, "role"=>"playera", "points"=>2, "result"=>80, "innings"=>17, "gd"=>4.71, "hs"=>26, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006428, "player_id"=>255, "role"=>"playera", "points"=>2, "result"=>80, "innings"=>17, "gd"=>4.71, "hs"=>26, "gname"=>nil)
    obj.game_id = game_id_map[50006428] if game_id_map[50006428].present?
    data = {"results"=>{"Gr."=>"group1:1-4", "Ergebnis"=>80, "Aufnahme"=>17, "GD"=>4.71, "HS"=>26, "gp_id"=>50012682}}
    obj.data = data
    created_at = Time.at(1631293644.3653572)
    updated_at = Time.at(1631365360.3830578)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012682] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012682] = id
  end
end
created_at = Time.at(1631293644.3767622)
updated_at = Time.at(1631365360.5684779)
obj_was = GameParticipation.where("id"=>50012683, "game_id"=>50006428, "player_id"=>266, "role"=>"playerb", "points"=>0, "result"=>57, "innings"=>17, "gd"=>3.35, "hs"=>17, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006428, "player_id"=>266, "role"=>"playerb", "points"=>0, "result"=>57, "innings"=>17, "gd"=>3.35, "hs"=>17, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006428, "player_id"=>266, "role"=>"playerb", "points"=>0, "result"=>57, "innings"=>17, "gd"=>3.35, "hs"=>17, "gname"=>nil)
    obj.game_id = game_id_map[50006428] if game_id_map[50006428].present?
    data = {"results"=>{"Gr."=>"group1:1-4", "Ergebnis"=>57, "Aufnahme"=>17, "GD"=>3.35, "HS"=>17, "gp_id"=>50012683}}
    obj.data = data
    created_at = Time.at(1631293644.3767622)
    updated_at = Time.at(1631365360.5684779)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012683] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012683] = id
  end
end
created_at = Time.at(1631293644.4007812)
updated_at = Time.at(1631360349.466611)
obj_was = GameParticipation.where("id"=>50012684, "game_id"=>50006429, "player_id"=>255, "role"=>"playera", "points"=>2, "result"=>71, "innings"=>20, "gd"=>3.55, "hs"=>14, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006429, "player_id"=>255, "role"=>"playera", "points"=>2, "result"=>71, "innings"=>20, "gd"=>3.55, "hs"=>14, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006429, "player_id"=>255, "role"=>"playera", "points"=>2, "result"=>71, "innings"=>20, "gd"=>3.55, "hs"=>14, "gname"=>nil)
    obj.game_id = game_id_map[50006429] if game_id_map[50006429].present?
    data = {"results"=>{"Gr."=>"group1:1-5", "Ergebnis"=>71, "Aufnahme"=>20, "GD"=>3.55, "HS"=>14, "gp_id"=>50012684}}
    obj.data = data
    created_at = Time.at(1631293644.4007812)
    updated_at = Time.at(1631360349.466611)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012684] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012684] = id
  end
end
created_at = Time.at(1631293644.412438)
updated_at = Time.at(1631360349.6445272)
obj_was = GameParticipation.where("id"=>50012685, "game_id"=>50006429, "player_id"=>294, "role"=>"playerb", "points"=>0, "result"=>41, "innings"=>20, "gd"=>2.05, "hs"=>12, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006429, "player_id"=>294, "role"=>"playerb", "points"=>0, "result"=>41, "innings"=>20, "gd"=>2.05, "hs"=>12, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006429, "player_id"=>294, "role"=>"playerb", "points"=>0, "result"=>41, "innings"=>20, "gd"=>2.05, "hs"=>12, "gname"=>nil)
    obj.game_id = game_id_map[50006429] if game_id_map[50006429].present?
    data = {"results"=>{"Gr."=>"group1:1-5", "Ergebnis"=>41, "Aufnahme"=>20, "GD"=>2.05, "HS"=>12, "gp_id"=>50012685}}
    obj.data = data
    created_at = Time.at(1631293644.412438)
    updated_at = Time.at(1631360349.6445272)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012685] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012685] = id
  end
end
created_at = Time.at(1631293644.436307)
updated_at = Time.at(1631355649.631218)
obj_was = GameParticipation.where("id"=>50012686, "game_id"=>50006430, "player_id"=>255, "role"=>"playera", "points"=>0, "result"=>66, "innings"=>20, "gd"=>3.3, "hs"=>25, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006430, "player_id"=>255, "role"=>"playera", "points"=>0, "result"=>66, "innings"=>20, "gd"=>3.3, "hs"=>25, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006430, "player_id"=>255, "role"=>"playera", "points"=>0, "result"=>66, "innings"=>20, "gd"=>3.3, "hs"=>25, "gname"=>nil)
    obj.game_id = game_id_map[50006430] if game_id_map[50006430].present?
    data = {"results"=>{"Gr."=>"group1:1-6", "Ergebnis"=>66, "Aufnahme"=>20, "GD"=>3.3, "HS"=>25, "gp_id"=>50012686}}
    obj.data = data
    created_at = Time.at(1631293644.436307)
    updated_at = Time.at(1631355649.631218)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012686] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012686] = id
  end
end
created_at = Time.at(1631293644.447916)
updated_at = Time.at(1631355649.802368)
obj_was = GameParticipation.where("id"=>50012687, "game_id"=>50006430, "player_id"=>252, "role"=>"playerb", "points"=>2, "result"=>69, "innings"=>20, "gd"=>3.45, "hs"=>17, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006430, "player_id"=>252, "role"=>"playerb", "points"=>2, "result"=>69, "innings"=>20, "gd"=>3.45, "hs"=>17, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006430, "player_id"=>252, "role"=>"playerb", "points"=>2, "result"=>69, "innings"=>20, "gd"=>3.45, "hs"=>17, "gname"=>nil)
    obj.game_id = game_id_map[50006430] if game_id_map[50006430].present?
    data = {"results"=>{"Gr."=>"group1:1-6", "Ergebnis"=>69, "Aufnahme"=>20, "GD"=>3.45, "HS"=>17, "gp_id"=>50012687}}
    obj.data = data
    created_at = Time.at(1631293644.447916)
    updated_at = Time.at(1631355649.802368)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012687] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012687] = id
  end
end
created_at = Time.at(1631293644.471982)
updated_at = Time.at(1631365360.769675)
obj_was = GameParticipation.where("id"=>50012688, "game_id"=>50006431, "player_id"=>259, "role"=>"playera", "points"=>0, "result"=>43, "innings"=>20, "gd"=>2.15, "hs"=>9, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006431, "player_id"=>259, "role"=>"playera", "points"=>0, "result"=>43, "innings"=>20, "gd"=>2.15, "hs"=>9, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006431, "player_id"=>259, "role"=>"playera", "points"=>0, "result"=>43, "innings"=>20, "gd"=>2.15, "hs"=>9, "gname"=>nil)
    obj.game_id = game_id_map[50006431] if game_id_map[50006431].present?
    data = {"results"=>{"Gr."=>"group1:2-3", "Ergebnis"=>43, "Aufnahme"=>20, "GD"=>2.15, "HS"=>9, "gp_id"=>50012688}}
    obj.data = data
    created_at = Time.at(1631293644.471982)
    updated_at = Time.at(1631365360.769675)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012688] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012688] = id
  end
end
created_at = Time.at(1631293644.483791)
updated_at = Time.at(1631365360.959347)
obj_was = GameParticipation.where("id"=>50012689, "game_id"=>50006431, "player_id"=>297, "role"=>"playerb", "points"=>2, "result"=>77, "innings"=>20, "gd"=>3.85, "hs"=>14, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006431, "player_id"=>297, "role"=>"playerb", "points"=>2, "result"=>77, "innings"=>20, "gd"=>3.85, "hs"=>14, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006431, "player_id"=>297, "role"=>"playerb", "points"=>2, "result"=>77, "innings"=>20, "gd"=>3.85, "hs"=>14, "gname"=>nil)
    obj.game_id = game_id_map[50006431] if game_id_map[50006431].present?
    data = {"results"=>{"Gr."=>"group1:2-3", "Ergebnis"=>77, "Aufnahme"=>20, "GD"=>3.85, "HS"=>14, "gp_id"=>50012689}}
    obj.data = data
    created_at = Time.at(1631293644.483791)
    updated_at = Time.at(1631365360.959347)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012689] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012689] = id
  end
end
created_at = Time.at(1631293644.508406)
updated_at = Time.at(1631360348.864933)
obj_was = GameParticipation.where("id"=>50012690, "game_id"=>50006432, "player_id"=>259, "role"=>"playerb", "points"=>2, "result"=>54, "innings"=>20, "gd"=>2.7, "hs"=>13, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006432, "player_id"=>259, "role"=>"playerb", "points"=>2, "result"=>54, "innings"=>20, "gd"=>2.7, "hs"=>13, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006432, "player_id"=>259, "role"=>"playerb", "points"=>2, "result"=>54, "innings"=>20, "gd"=>2.7, "hs"=>13, "gname"=>nil)
    obj.game_id = game_id_map[50006432] if game_id_map[50006432].present?
    data = {"results"=>{"Gr."=>"group1:2-4", "Ergebnis"=>54, "Aufnahme"=>20, "GD"=>2.7, "HS"=>13, "gp_id"=>50012690}}
    obj.data = data
    created_at = Time.at(1631293644.508406)
    updated_at = Time.at(1631360348.864933)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012690] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012690] = id
  end
end
created_at = Time.at(1631293644.520065)
updated_at = Time.at(1631360348.675882)
obj_was = GameParticipation.where("id"=>50012691, "game_id"=>50006432, "player_id"=>266, "role"=>"playera", "points"=>0, "result"=>52, "innings"=>20, "gd"=>2.6, "hs"=>8, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006432, "player_id"=>266, "role"=>"playera", "points"=>0, "result"=>52, "innings"=>20, "gd"=>2.6, "hs"=>8, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006432, "player_id"=>266, "role"=>"playera", "points"=>0, "result"=>52, "innings"=>20, "gd"=>2.6, "hs"=>8, "gname"=>nil)
    obj.game_id = game_id_map[50006432] if game_id_map[50006432].present?
    data = {"results"=>{"Gr."=>"group1:2-4", "Ergebnis"=>52, "Aufnahme"=>20, "GD"=>2.6, "HS"=>8, "gp_id"=>50012691}}
    obj.data = data
    created_at = Time.at(1631293644.520065)
    updated_at = Time.at(1631360348.675882)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012691] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012691] = id
  end
end
created_at = Time.at(1631293644.544565)
updated_at = Time.at(1631355648.716515)
obj_was = GameParticipation.where("id"=>50012692, "game_id"=>50006433, "player_id"=>259, "role"=>"playera", "points"=>2, "result"=>49, "innings"=>20, "gd"=>2.45, "hs"=>16, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006433, "player_id"=>259, "role"=>"playera", "points"=>2, "result"=>49, "innings"=>20, "gd"=>2.45, "hs"=>16, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006433, "player_id"=>259, "role"=>"playera", "points"=>2, "result"=>49, "innings"=>20, "gd"=>2.45, "hs"=>16, "gname"=>nil)
    obj.game_id = game_id_map[50006433] if game_id_map[50006433].present?
    data = {"results"=>{"Gr."=>"group1:2-5", "Ergebnis"=>49, "Aufnahme"=>20, "GD"=>2.45, "HS"=>16, "gp_id"=>50012692}}
    obj.data = data
    created_at = Time.at(1631293644.544565)
    updated_at = Time.at(1631355648.716515)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012692] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012692] = id
  end
end
created_at = Time.at(1631293644.556397)
updated_at = Time.at(1631355648.929903)
obj_was = GameParticipation.where("id"=>50012693, "game_id"=>50006433, "player_id"=>294, "role"=>"playerb", "points"=>0, "result"=>44, "innings"=>20, "gd"=>2.2, "hs"=>9, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006433, "player_id"=>294, "role"=>"playerb", "points"=>0, "result"=>44, "innings"=>20, "gd"=>2.2, "hs"=>9, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006433, "player_id"=>294, "role"=>"playerb", "points"=>0, "result"=>44, "innings"=>20, "gd"=>2.2, "hs"=>9, "gname"=>nil)
    obj.game_id = game_id_map[50006433] if game_id_map[50006433].present?
    data = {"results"=>{"Gr."=>"group1:2-5", "Ergebnis"=>44, "Aufnahme"=>20, "GD"=>2.2, "HS"=>9, "gp_id"=>50012693}}
    obj.data = data
    created_at = Time.at(1631293644.556397)
    updated_at = Time.at(1631355648.929903)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012693] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012693] = id
  end
end
created_at = Time.at(1631293644.5807161)
updated_at = Time.at(1631372319.428591)
obj_was = GameParticipation.where("id"=>50012694, "game_id"=>50006434, "player_id"=>259, "role"=>"playerb", "points"=>2, "result"=>78, "innings"=>20, "gd"=>3.9, "hs"=>16, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006434, "player_id"=>259, "role"=>"playerb", "points"=>2, "result"=>78, "innings"=>20, "gd"=>3.9, "hs"=>16, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006434, "player_id"=>259, "role"=>"playerb", "points"=>2, "result"=>78, "innings"=>20, "gd"=>3.9, "hs"=>16, "gname"=>nil)
    obj.game_id = game_id_map[50006434] if game_id_map[50006434].present?
    data = {"results"=>{"Gr."=>"group1:2-6", "Ergebnis"=>78, "Aufnahme"=>20, "GD"=>3.9, "HS"=>16, "gp_id"=>50012694}}
    obj.data = data
    created_at = Time.at(1631293644.5807161)
    updated_at = Time.at(1631372319.428591)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012694] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012694] = id
  end
end
created_at = Time.at(1631293644.592445)
updated_at = Time.at(1631372319.230391)
obj_was = GameParticipation.where("id"=>50012695, "game_id"=>50006434, "player_id"=>252, "role"=>"playera", "points"=>0, "result"=>68, "innings"=>20, "gd"=>3.4, "hs"=>11, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006434, "player_id"=>252, "role"=>"playera", "points"=>0, "result"=>68, "innings"=>20, "gd"=>3.4, "hs"=>11, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006434, "player_id"=>252, "role"=>"playera", "points"=>0, "result"=>68, "innings"=>20, "gd"=>3.4, "hs"=>11, "gname"=>nil)
    obj.game_id = game_id_map[50006434] if game_id_map[50006434].present?
    data = {"results"=>{"Gr."=>"group1:2-6", "Ergebnis"=>68, "Aufnahme"=>20, "GD"=>3.4, "HS"=>11, "gp_id"=>50012695}}
    obj.data = data
    created_at = Time.at(1631293644.592445)
    updated_at = Time.at(1631372319.230391)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012695] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012695] = id
  end
end
created_at = Time.at(1631293644.61698)
updated_at = Time.at(1631355649.3817768)
obj_was = GameParticipation.where("id"=>50012696, "game_id"=>50006435, "player_id"=>297, "role"=>"playerb", "points"=>2, "result"=>69, "innings"=>20, "gd"=>3.45, "hs"=>11, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006435, "player_id"=>297, "role"=>"playerb", "points"=>2, "result"=>69, "innings"=>20, "gd"=>3.45, "hs"=>11, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006435, "player_id"=>297, "role"=>"playerb", "points"=>2, "result"=>69, "innings"=>20, "gd"=>3.45, "hs"=>11, "gname"=>nil)
    obj.game_id = game_id_map[50006435] if game_id_map[50006435].present?
    data = {"results"=>{"Gr."=>"group1:3-4", "Ergebnis"=>69, "Aufnahme"=>20, "GD"=>3.45, "HS"=>11, "gp_id"=>50012696}}
    obj.data = data
    created_at = Time.at(1631293644.61698)
    updated_at = Time.at(1631355649.3817768)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012696] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012696] = id
  end
end
created_at = Time.at(1631293644.628684)
updated_at = Time.at(1631355649.158699)
obj_was = GameParticipation.where("id"=>50012697, "game_id"=>50006435, "player_id"=>266, "role"=>"playera", "points"=>0, "result"=>24, "innings"=>20, "gd"=>1.2, "hs"=>7, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006435, "player_id"=>266, "role"=>"playera", "points"=>0, "result"=>24, "innings"=>20, "gd"=>1.2, "hs"=>7, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006435, "player_id"=>266, "role"=>"playera", "points"=>0, "result"=>24, "innings"=>20, "gd"=>1.2, "hs"=>7, "gname"=>nil)
    obj.game_id = game_id_map[50006435] if game_id_map[50006435].present?
    data = {"results"=>{"Gr."=>"group1:3-4", "Ergebnis"=>24, "Aufnahme"=>20, "GD"=>1.2, "HS"=>7, "gp_id"=>50012697}}
    obj.data = data
    created_at = Time.at(1631293644.628684)
    updated_at = Time.at(1631355649.158699)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012697] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012697] = id
  end
end
created_at = Time.at(1631293644.65318)
updated_at = Time.at(1631293644.65318)
obj_was = GameParticipation.where("id"=>50012698, "game_id"=>50006436, "player_id"=>297, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006436, "player_id"=>297, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006436, "player_id"=>297, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006436] if game_id_map[50006436].present?
    created_at = Time.at(1631293644.65318)
    updated_at = Time.at(1631293644.65318)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012698] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012698] = id
  end
end
created_at = Time.at(1631293644.66516)
updated_at = Time.at(1631293644.66516)
obj_was = GameParticipation.where("id"=>50012699, "game_id"=>50006436, "player_id"=>294, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006436, "player_id"=>294, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006436, "player_id"=>294, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006436] if game_id_map[50006436].present?
    created_at = Time.at(1631293644.66516)
    updated_at = Time.at(1631293644.66516)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012699] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012699] = id
  end
end
created_at = Time.at(1631293644.713344)
updated_at = Time.at(1631360349.250294)
obj_was = GameParticipation.where("id"=>50012700, "game_id"=>50006437, "player_id"=>297, "role"=>"playerb", "points"=>2, "result"=>45, "innings"=>20, "gd"=>2.25, "hs"=>11, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006437, "player_id"=>297, "role"=>"playerb", "points"=>2, "result"=>45, "innings"=>20, "gd"=>2.25, "hs"=>11, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006437, "player_id"=>297, "role"=>"playerb", "points"=>2, "result"=>45, "innings"=>20, "gd"=>2.25, "hs"=>11, "gname"=>nil)
    obj.game_id = game_id_map[50006437] if game_id_map[50006437].present?
    data = {"results"=>{"Gr."=>"group1:3-6", "Ergebnis"=>45, "Aufnahme"=>20, "GD"=>2.25, "HS"=>11, "gp_id"=>50012700}}
    obj.data = data
    created_at = Time.at(1631293644.713344)
    updated_at = Time.at(1631360349.250294)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012700] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012700] = id
  end
end
created_at = Time.at(1631293644.725461)
updated_at = Time.at(1631360349.070518)
obj_was = GameParticipation.where("id"=>50012701, "game_id"=>50006437, "player_id"=>252, "role"=>"playera", "points"=>0, "result"=>41, "innings"=>20, "gd"=>2.05, "hs"=>14, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006437, "player_id"=>252, "role"=>"playera", "points"=>0, "result"=>41, "innings"=>20, "gd"=>2.05, "hs"=>14, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006437, "player_id"=>252, "role"=>"playera", "points"=>0, "result"=>41, "innings"=>20, "gd"=>2.05, "hs"=>14, "gname"=>nil)
    obj.game_id = game_id_map[50006437] if game_id_map[50006437].present?
    data = {"results"=>{"Gr."=>"group1:3-6", "Ergebnis"=>41, "Aufnahme"=>20, "GD"=>2.05, "HS"=>14, "gp_id"=>50012701}}
    obj.data = data
    created_at = Time.at(1631293644.725461)
    updated_at = Time.at(1631360349.070518)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012701] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012701] = id
  end
end
created_at = Time.at(1631293644.749624)
updated_at = Time.at(1631372318.8253162)
obj_was = GameParticipation.where("id"=>50012702, "game_id"=>50006438, "player_id"=>266, "role"=>"playera", "points"=>2, "result"=>69, "innings"=>20, "gd"=>3.45, "hs"=>20, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006438, "player_id"=>266, "role"=>"playera", "points"=>2, "result"=>69, "innings"=>20, "gd"=>3.45, "hs"=>20, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006438, "player_id"=>266, "role"=>"playera", "points"=>2, "result"=>69, "innings"=>20, "gd"=>3.45, "hs"=>20, "gname"=>nil)
    obj.game_id = game_id_map[50006438] if game_id_map[50006438].present?
    data = {"results"=>{"Gr."=>"group1:4-5", "Ergebnis"=>69, "Aufnahme"=>20, "GD"=>3.45, "HS"=>20, "gp_id"=>50012702}}
    obj.data = data
    created_at = Time.at(1631293644.749624)
    updated_at = Time.at(1631372318.8253162)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012702] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012702] = id
  end
end
created_at = Time.at(1631293644.761261)
updated_at = Time.at(1631372319.028096)
obj_was = GameParticipation.where("id"=>50012703, "game_id"=>50006438, "player_id"=>294, "role"=>"playerb", "points"=>0, "result"=>51, "innings"=>20, "gd"=>2.55, "hs"=>14, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006438, "player_id"=>294, "role"=>"playerb", "points"=>0, "result"=>51, "innings"=>20, "gd"=>2.55, "hs"=>14, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006438, "player_id"=>294, "role"=>"playerb", "points"=>0, "result"=>51, "innings"=>20, "gd"=>2.55, "hs"=>14, "gname"=>nil)
    obj.game_id = game_id_map[50006438] if game_id_map[50006438].present?
    data = {"results"=>{"Gr."=>"group1:4-5", "Ergebnis"=>51, "Aufnahme"=>20, "GD"=>2.55, "HS"=>14, "gp_id"=>50012703}}
    obj.data = data
    created_at = Time.at(1631293644.761261)
    updated_at = Time.at(1631372319.028096)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012703] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012703] = id
  end
end
created_at = Time.at(1631293644.785001)
updated_at = Time.at(1631372460.501578)
obj_was = GameParticipation.where("id"=>50012704, "game_id"=>50006439, "player_id"=>266, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006439, "player_id"=>266, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006439, "player_id"=>266, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006439] if game_id_map[50006439].present?
    created_at = Time.at(1631293644.785001)
    updated_at = Time.at(1631372460.501578)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012704] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012704] = id
  end
end
created_at = Time.at(1631293644.796371)
updated_at = Time.at(1631372460.2980192)
obj_was = GameParticipation.where("id"=>50012705, "game_id"=>50006439, "player_id"=>252, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006439, "player_id"=>252, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006439, "player_id"=>252, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006439] if game_id_map[50006439].present?
    created_at = Time.at(1631293644.796371)
    updated_at = Time.at(1631372460.2980192)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012705] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012705] = id
  end
end
created_at = Time.at(1631293644.820713)
updated_at = Time.at(1631365360.180663)
obj_was = GameParticipation.where("id"=>50012706, "game_id"=>50006440, "player_id"=>294, "role"=>"playerb", "points"=>0, "result"=>42, "innings"=>20, "gd"=>2.1, "hs"=>14, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006440, "player_id"=>294, "role"=>"playerb", "points"=>0, "result"=>42, "innings"=>20, "gd"=>2.1, "hs"=>14, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006440, "player_id"=>294, "role"=>"playerb", "points"=>0, "result"=>42, "innings"=>20, "gd"=>2.1, "hs"=>14, "gname"=>nil)
    obj.game_id = game_id_map[50006440] if game_id_map[50006440].present?
    data = {"results"=>{"Gr."=>"group1:5-6", "Ergebnis"=>42, "Aufnahme"=>20, "GD"=>2.1, "HS"=>14, "gp_id"=>50012706}}
    obj.data = data
    created_at = Time.at(1631293644.820713)
    updated_at = Time.at(1631365360.180663)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012706] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012706] = id
  end
end
created_at = Time.at(1631293644.832521)
updated_at = Time.at(1631365359.9901628)
obj_was = GameParticipation.where("id"=>50012707, "game_id"=>50006440, "player_id"=>252, "role"=>"playera", "points"=>2, "result"=>45, "innings"=>20, "gd"=>2.25, "hs"=>13, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006440, "player_id"=>252, "role"=>"playera", "points"=>2, "result"=>45, "innings"=>20, "gd"=>2.25, "hs"=>13, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006440, "player_id"=>252, "role"=>"playera", "points"=>2, "result"=>45, "innings"=>20, "gd"=>2.25, "hs"=>13, "gname"=>nil)
    obj.game_id = game_id_map[50006440] if game_id_map[50006440].present?
    data = {"results"=>{"Gr."=>"group1:5-6", "Ergebnis"=>45, "Aufnahme"=>20, "GD"=>2.25, "HS"=>13, "gp_id"=>50012707}}
    obj.data = data
    created_at = Time.at(1631293644.832521)
    updated_at = Time.at(1631365359.9901628)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012707] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012707] = id
  end
end
created_at = Time.at(1631349185.4230778)
updated_at = Time.at(1631349531.788471)
obj_was = GameParticipation.where("id"=>50012720, "game_id"=>50006444, "player_id"=>252, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006444, "player_id"=>252, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006444, "player_id"=>252, "role"=>"playerb", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006444] if game_id_map[50006444].present?
    created_at = Time.at(1631349185.4230778)
    updated_at = Time.at(1631349531.788471)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012720] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012720] = id
  end
end
created_at = Time.at(1631349185.450969)
updated_at = Time.at(1631349531.815984)
obj_was = GameParticipation.where("id"=>50012721, "game_id"=>50006444, "player_id"=>255, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = GameParticipation.where("game_id"=>50006444, "player_id"=>255, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil).first
  if obj_was.blank?
    obj = GameParticipation.new("game_id"=>50006444, "player_id"=>255, "role"=>"playera", "points"=>nil, "result"=>nil, "innings"=>nil, "gd"=>nil, "hs"=>nil, "gname"=>nil)
    obj.game_id = game_id_map[50006444] if game_id_map[50006444].present?
    created_at = Time.at(1631349185.450969)
    updated_at = Time.at(1631349531.815984)
    begin
      obj.save!
      id = obj.id
      game_participation_id_map[50012721] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    game_participation_id_map[50012721] = id
  end
end
tournament_monitor_id_map = {}
created_at = Time.at(1629042224.411969)
updated_at = Time.at(1630493762.9385312)
obj_was = TournamentMonitor.where("id"=>50000198, "tournament_id"=>50000003, "state"=>"playing_groups", "innings_goal"=>nil, "balls_goal"=>nil, "timeouts"=>0, "timeout"=>0, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = TournamentMonitor.where("tournament_id"=>50000003, "state"=>"playing_groups", "innings_goal"=>nil, "balls_goal"=>nil, "timeouts"=>0, "timeout"=>0).first
  if obj_was.blank?
    obj = TournamentMonitor.new("tournament_id"=>50000003, "state"=>"playing_groups", "innings_goal"=>nil, "balls_goal"=>nil, "timeouts"=>0, "timeout"=>0)
    obj.tournament_id = tournament_id_map[50000003] if tournament_id_map[50000003].present?
    data = {"current_round"=>1, "groups"=>{"group1"=>[{"id"=>261, "ba_id"=>366548, "club_id"=>357, "lastname"=>"Richter", "firstname"=>"Joachim", "title"=>"Herr", "created_at"=>"2020-09-20T16:04:47.014+02:00", "updated_at"=>"2020-09-20T16:04:47.972+02:00", "guest"=>false}, {"id"=>257, "ba_id"=>121315, "club_id"=>357, "lastname"=>"Meißner", "firstname"=>"Andreas", "title"=>"Herr", "created_at"=>"2020-09-20T16:04:43.559+02:00", "updated_at"=>"2020-09-20T16:04:44.423+02:00", "guest"=>false}, {"id"=>255, "ba_id"=>352853, "club_id"=>357, "lastname"=>"Langemann", "firstname"=>"Nils", "title"=>"Herr", "created_at"=>"2020-09-20T16:04:42.142+02:00", "updated_at"=>"2020-09-20T16:04:42.868+02:00", "guest"=>false}, {"id"=>266, "ba_id"=>121340, "club_id"=>357, "lastname"=>"Ullrich", "firstname"=>"Dr. Gernot", "title"=>"Herr", "created_at"=>"2020-09-20T16:04:51.152+02:00", "updated_at"=>"2020-09-20T16:04:51.871+02:00", "guest"=>false}, {"id"=>254, "ba_id"=>224762, "club_id"=>357, "lastname"=>"Kollei", "firstname"=>"Werner", "title"=>"Herr", "created_at"=>"2020-09-20T16:04:41.161+02:00", "updated_at"=>"2020-09-20T16:04:42.135+02:00", "guest"=>false}, {"id"=>247, "ba_id"=>239940, "club_id"=>357, "lastname"=>"Auel", "firstname"=>"Wilfried", "title"=>"Herr", "created_at"=>"2020-09-20T16:04:35.597+02:00", "updated_at"=>"2020-09-20T16:04:36.463+02:00", "guest"=>false}, {"id"=>263, "ba_id"=>246783, "club_id"=>357, "lastname"=>"Schröder", "firstname"=>"Jan", "title"=>"Herr", "created_at"=>"2020-09-20T16:04:48.596+02:00", "updated_at"=>"2020-09-20T16:04:49.414+02:00", "guest"=>false}, {"id"=>249, "ba_id"=>224758, "club_id"=>357, "lastname"=>"Förthmann", "firstname"=>"Rene", "title"=>"Herr", "created_at"=>"2020-09-20T16:04:37.255+02:00", "updated_at"=>"2020-09-20T16:04:38.096+02:00", "guest"=>false}], "group2"=>[{"id"=>265, "ba_id"=>121333, "club_id"=>357, "lastname"=>"Sporleder", "firstname"=>"Lorenz", "title"=>"Herr", "created_at"=>"2020-09-20T16:04:50.097+02:00", "updated_at"=>"2020-09-20T16:04:51.145+02:00", "guest"=>false}, {"id"=>267, "ba_id"=>121341, "club_id"=>357, "lastname"=>"Unger", "firstname"=>"Dr. Jörg", "title"=>"Herr", "created_at"=>"2020-09-20T16:04:51.878+02:00", "updated_at"=>"2020-09-26T04:31:18.359+02:00", "guest"=>false}, {"id"=>262, "ba_id"=>121329, "club_id"=>357, "lastname"=>"Schröder", "firstname"=>"Hans-Jörg", "title"=>"Herr", "created_at"=>"2020-09-20T16:04:47.975+02:00", "updated_at"=>"2020-09-20T16:04:48.593+02:00", "guest"=>false}, {"id"=>252, "ba_id"=>352025, "club_id"=>357, "lastname"=>"Kämmer", "firstname"=>"Lothar", "title"=>"Herr", "created_at"=>"2020-09-20T16:04:39.614+02:00", "updated_at"=>"2020-09-20T16:04:40.307+02:00", "guest"=>false}, {"id"=>50000001, "ba_id"=>nil, "club_id"=>357, "lastname"=>"von Husen", "firstname"=>"Jonny", "title"=>"", "created_at"=>"2021-08-11T17:27:55.874+02:00", "updated_at"=>"2021-08-11T17:27:55.874+02:00", "guest"=>true}, {"id"=>256, "ba_id"=>356386, "club_id"=>357, "lastname"=>"Maruska", "firstname"=>"Felix", "title"=>"Herr", "created_at"=>"2020-09-20T16:04:42.870+02:00", "updated_at"=>"2020-09-20T16:04:43.556+02:00", "guest"=>false}, {"id"=>251, "ba_id"=>355477, "club_id"=>357, "lastname"=>"Grimm", "firstname"=>"Juri", "title"=>"Herr", "created_at"=>"2020-09-20T16:04:38.967+02:00", "updated_at"=>"2020-09-20T16:04:39.607+02:00", "guest"=>false}, {"id"=>260, "ba_id"=>352574, "club_id"=>357, "lastname"=>"Rerrer", "firstname"=>"Nils", "title"=>"Herr", "created_at"=>"2020-09-20T16:04:45.903+02:00", "updated_at"=>"2020-09-20T16:04:47.011+02:00", "guest"=>false}]}, "placements"=>{}, "rankings"=>{"total"=>{249=>{"points"=>12, "result"=>99, "innings"=>78, "hs"=>8, "bed"=>2.67, "gd"=>1.27}, 257=>{"points"=>8, "result"=>315, "innings"=>60, "hs"=>36, "bed"=>15.0, "gd"=>5.25}, 254=>{"points"=>12, "result"=>95, "innings"=>67, "hs"=>6, "bed"=>2.0, "gd"=>1.42}, 266=>{"points"=>6, "result"=>147, "innings"=>42, "hs"=>16, "bed"=>6.0, "gd"=>3.5}, 262=>{"points"=>4, "result"=>173, "innings"=>41, "hs"=>28, "bed"=>8.57, "gd"=>4.22}, 267=>{"points"=>2, "result"=>529, "innings"=>72, "hs"=>55, "bed"=>12.0, "gd"=>7.35}, 263=>{"points"=>0, "result"=>27, "innings"=>50, "hs"=>5, "bed"=>1.0, "gd"=>0.54}, 255=>{"points"=>2, "result"=>181, "innings"=>57, "hs"=>21, "bed"=>4.62, "gd"=>3.18}, 261=>{"points"=>0, "result"=>184, "innings"=>69, "hs"=>17, "bed"=>3.73, "gd"=>2.67}, 247=>{"points"=>8, "result"=>71, "innings"=>52, "hs"=>6, "bed"=>2.29, "gd"=>1.37}, 50000001=>{"points"=>2, "result"=>57, "innings"=>54, "hs"=>10, "bed"=>2.67, "gd"=>1.06}, 252=>{"points"=>6, "result"=>105, "innings"=>38, "hs"=>10, "bed"=>4.57, "gd"=>2.76}, 256=>{"points"=>2, "result"=>16, "innings"=>22, "hs"=>2, "bed"=>0.73, "gd"=>0.73}, 260=>{"points"=>6, "result"=>100, "innings"=>43, "hs"=>11, "bed"=>3.2, "gd"=>2.33}}, "groups"=>{"total"=>{249=>{"points"=>12, "result"=>99, "innings"=>78, "hs"=>8, "bed"=>2.67, "gd"=>1.27}, 257=>{"points"=>8, "result"=>315, "innings"=>60, "hs"=>36, "bed"=>15.0, "gd"=>5.25}, 254=>{"points"=>12, "result"=>95, "innings"=>67, "hs"=>6, "bed"=>2.0, "gd"=>1.42}, 266=>{"points"=>6, "result"=>147, "innings"=>42, "hs"=>16, "bed"=>6.0, "gd"=>3.5}, 262=>{"points"=>4, "result"=>173, "innings"=>41, "hs"=>28, "bed"=>8.57, "gd"=>4.22}, 267=>{"points"=>2, "result"=>529, "innings"=>72, "hs"=>55, "bed"=>12.0, "gd"=>7.35}, 263=>{"points"=>0, "result"=>27, "innings"=>50, "hs"=>5, "bed"=>1.0, "gd"=>0.54}, 255=>{"points"=>2, "result"=>181, "innings"=>57, "hs"=>21, "bed"=>4.62, "gd"=>3.18}, 261=>{"points"=>0, "result"=>184, "innings"=>69, "hs"=>17, "bed"=>3.73, "gd"=>2.67}, 247=>{"points"=>8, "result"=>71, "innings"=>52, "hs"=>6, "bed"=>2.29, "gd"=>1.37}, 50000001=>{"points"=>2, "result"=>57, "innings"=>54, "hs"=>10, "bed"=>2.67, "gd"=>1.06}, 252=>{"points"=>6, "result"=>105, "innings"=>38, "hs"=>10, "bed"=>4.57, "gd"=>2.76}, 256=>{"points"=>2, "result"=>16, "innings"=>22, "hs"=>2, "bed"=>0.73, "gd"=>0.73}, 260=>{"points"=>6, "result"=>100, "innings"=>43, "hs"=>11, "bed"=>3.2, "gd"=>2.33}}, "group1"=>{249=>{"points"=>12, "result"=>99, "innings"=>78, "hs"=>8, "bed"=>2.67, "gd"=>1.27}, 257=>{"points"=>8, "result"=>315, "innings"=>60, "hs"=>36, "bed"=>15.0, "gd"=>5.25}, 254=>{"points"=>12, "result"=>95, "innings"=>67, "hs"=>6, "bed"=>2.0, "gd"=>1.42}, 266=>{"points"=>6, "result"=>147, "innings"=>42, "hs"=>16, "bed"=>6.0, "gd"=>3.5}, 263=>{"points"=>0, "result"=>27, "innings"=>50, "hs"=>5, "bed"=>1.0, "gd"=>0.54}, 255=>{"points"=>2, "result"=>181, "innings"=>57, "hs"=>21, "bed"=>4.62, "gd"=>3.18}, 261=>{"points"=>0, "result"=>184, "innings"=>69, "hs"=>17, "bed"=>3.73, "gd"=>2.67}, 247=>{"points"=>8, "result"=>71, "innings"=>52, "hs"=>6, "bed"=>2.29, "gd"=>1.37}}, "group2"=>{262=>{"points"=>4, "result"=>173, "innings"=>41, "hs"=>28, "bed"=>8.57, "gd"=>4.22}, 267=>{"points"=>2, "result"=>529, "innings"=>72, "hs"=>55, "bed"=>12.0, "gd"=>7.35}, 50000001=>{"points"=>2, "result"=>57, "innings"=>54, "hs"=>10, "bed"=>2.67, "gd"=>1.06}, 252=>{"points"=>6, "result"=>105, "innings"=>38, "hs"=>10, "bed"=>4.57, "gd"=>2.76}, 256=>{"points"=>2, "result"=>16, "innings"=>22, "hs"=>2, "bed"=>0.73, "gd"=>0.73}, 260=>{"points"=>6, "result"=>100, "innings"=>43, "hs"=>11, "bed"=>3.2, "gd"=>2.33}}, "group3"=>{}, "group4"=>{}, "group5"=>{}, "group6"=>{}, "group7"=>{}, "group8"=>{}}, "endgames"=>{"total"=>{}, "groups"=>{"total"=>{}, "fg1"=>{}, "fg2"=>{}, "fg3"=>{}, "fg4"=>{}}, "af"=>{}, "af1"=>{}, "af2"=>{}, "af3"=>{}, "af4"=>{}, "af5"=>{}, "af6"=>{}, "af7"=>{}, "af8"=>{}, "qf"=>{}, "qf1"=>{}, "qf2"=>{}, "qf3"=>{}, "qf4"=>{}, "hf"=>{}, "hf1"=>{}, "hf2"=>{}, "fin"=>{}, "p<3-4>"=>{}, "p<5-6>"=>{}, "p<7-8>"=>{}, "p<5-8>"=>{}, "p<5-8>1"=>{}, "p<5-8>2"=>{}}}}
    obj.data = data
    created_at = Time.at(1629042224.411969)
    updated_at = Time.at(1630493762.9385312)
    begin
      obj.save!
      id = obj.id
      tournament_monitor_id_map[50000198] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    tournament_monitor_id_map[50000198] = id
  end
end
created_at = Time.at(1631293643.891478)
updated_at = Time.at(1631377410.6681159)
obj_was = TournamentMonitor.where("id"=>50000199, "tournament_id"=>11911, "state"=>"playing_groups", "innings_goal"=>nil, "balls_goal"=>nil, "timeouts"=>0, "timeout"=>0, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = TournamentMonitor.where("tournament_id"=>11911, "state"=>"playing_groups", "innings_goal"=>nil, "balls_goal"=>nil, "timeouts"=>0, "timeout"=>0).first
  if obj_was.blank?
    obj = TournamentMonitor.new("tournament_id"=>11911, "state"=>"playing_groups", "innings_goal"=>nil, "balls_goal"=>nil, "timeouts"=>0, "timeout"=>0)
    obj.tournament_id = tournament_id_map[11911] if tournament_id_map[11911].present?
    data = {"current_round"=>5, "groups"=>{"group1"=>[{"id"=>255, "ba_id"=>352853, "club_id"=>357, "lastname"=>"Langemann", "firstname"=>"Nils", "title"=>"Herr", "created_at"=>"2020-09-20T14:04:42.142Z", "updated_at"=>"2020-09-20T14:04:42.868Z", "guest"=>false, "nickname"=>nil}, {"id"=>259, "ba_id"=>156194, "club_id"=>357, "lastname"=>"Pusch", "firstname"=>"Dr. Christian", "title"=>"Herr", "created_at"=>"2020-09-20T14:04:45.084Z", "updated_at"=>"2020-09-20T14:04:45.899Z", "guest"=>false, "nickname"=>nil}, {"id"=>297, "ba_id"=>247211, "club_id"=>360, "lastname"=>"Jaruschewski", "firstname"=>"Kurt", "title"=>"Herr", "created_at"=>"2020-09-20T14:05:18.591Z", "updated_at"=>"2020-09-20T14:05:19.457Z", "guest"=>false, "nickname"=>nil}, {"id"=>266, "ba_id"=>121340, "club_id"=>357, "lastname"=>"Ullrich", "firstname"=>"Dr. Gernot", "title"=>"Herr", "created_at"=>"2020-09-20T14:04:51.152Z", "updated_at"=>"2020-09-20T14:04:51.871Z", "guest"=>false, "nickname"=>nil}, {"id"=>294, "ba_id"=>228105, "club_id"=>360, "lastname"=>"Balzer", "firstname"=>"Wolfgang", "title"=>"Herr", "created_at"=>"2020-09-20T14:05:15.674Z", "updated_at"=>"2020-09-20T14:05:16.848Z", "guest"=>false, "nickname"=>nil}, {"id"=>252, "ba_id"=>352025, "club_id"=>357, "lastname"=>"Kämmer", "firstname"=>"Lothar", "title"=>"Herr", "created_at"=>"2020-09-20T14:04:39.614Z", "updated_at"=>"2020-09-20T14:04:40.307Z", "guest"=>false, "nickname"=>nil}]}, "placements"=>{"round1"=>{"table1"=>50006433, "table2"=>50006435, "table3"=>50006430}, "round2"=>{"table1"=>50006437, "table2"=>50006429, "table3"=>50006432}, "round3"=>{"table1"=>50006428, "table2"=>50006431, "table3"=>50006440}, "round4"=>{"table1"=>50006438, "table2"=>50006434, "table3"=>50006427}, "round5"=>{"table1"=>50006426, "table2"=>50006439, "table3"=>50006436}}, "rankings"=>{"total"=>{252=>{"points"=>4, "result"=>223, "innings"=>80, "hs"=>17, "bed"=>3.45, "gd"=>2.79}, 297=>{"points"=>8, "result"=>271, "innings"=>77, "hs"=>27, "bed"=>4.71, "gd"=>3.52}, 259=>{"points"=>6, "result"=>224, "innings"=>80, "hs"=>16, "bed"=>3.9, "gd"=>2.8}, 255=>{"points"=>4, "result"=>277, "innings"=>74, "hs"=>26, "bed"=>4.71, "gd"=>3.74}, 294=>{"points"=>0, "result"=>178, "innings"=>80, "hs"=>14, "bed"=>2.55, "gd"=>2.22}, 266=>{"points"=>2, "result"=>202, "innings"=>77, "hs"=>20, "bed"=>3.45, "gd"=>2.62}}, "groups"=>{"total"=>{252=>{"points"=>4, "result"=>223, "innings"=>80, "hs"=>17, "bed"=>3.45, "gd"=>2.79}, 297=>{"points"=>8, "result"=>271, "innings"=>77, "hs"=>27, "bed"=>4.71, "gd"=>3.52}, 259=>{"points"=>6, "result"=>224, "innings"=>80, "hs"=>16, "bed"=>3.9, "gd"=>2.8}, 255=>{"points"=>4, "result"=>277, "innings"=>74, "hs"=>26, "bed"=>4.71, "gd"=>3.74}, 294=>{"points"=>0, "result"=>178, "innings"=>80, "hs"=>14, "bed"=>2.55, "gd"=>2.22}, 266=>{"points"=>2, "result"=>202, "innings"=>77, "hs"=>20, "bed"=>3.45, "gd"=>2.62}}, "group1"=>{252=>{"points"=>4, "result"=>223, "innings"=>80, "hs"=>17, "bed"=>3.45, "gd"=>2.79}, 297=>{"points"=>8, "result"=>271, "innings"=>77, "hs"=>27, "bed"=>4.71, "gd"=>3.52}, 259=>{"points"=>6, "result"=>224, "innings"=>80, "hs"=>16, "bed"=>3.9, "gd"=>2.8}, 255=>{"points"=>4, "result"=>277, "innings"=>74, "hs"=>26, "bed"=>4.71, "gd"=>3.74}, 294=>{"points"=>0, "result"=>178, "innings"=>80, "hs"=>14, "bed"=>2.55, "gd"=>2.22}, 266=>{"points"=>2, "result"=>202, "innings"=>77, "hs"=>20, "bed"=>3.45, "gd"=>2.62}}}, "endgames"=>{"total"=>{}, "groups"=>{"total"=>{}}}}}
    obj.data = data
    created_at = Time.at(1631293643.891478)
    updated_at = Time.at(1631377410.6681159)
    begin
      obj.save!
      id = obj.id
      tournament_monitor_id_map[50000199] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    tournament_monitor_id_map[50000199] = id
  end
end
table_monitor_id_map = {}
#+++TableMonitor+++
#---TournamentMonitor---
h1 = JSON.pretty_generate(tournament_monitor_id_map)
created_at = Time.at(1631196877.8120818)
updated_at = Time.at(1631377554.936971)
obj_was = TableMonitor.where("id"=>50000001, "tournament_monitor_id"=>50000199, "state"=>"game_result_reported", "name"=>"Tisch 5", "game_id"=>50006426, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"game_finished", "current_element"=>"game_state", "timer_job_id"=>nil, "clock_job_id"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = TableMonitor.where("tournament_monitor_id"=>50000199, "state"=>"game_result_reported", "name"=>"Tisch 5", "game_id"=>50006426, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"game_finished", "current_element"=>"game_state", "timer_job_id"=>nil, "clock_job_id"=>nil).first
  if obj_was.blank?
    obj = TableMonitor.new("tournament_monitor_id"=>50000199, "state"=>"game_result_reported", "name"=>"Tisch 5", "game_id"=>50006426, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"game_finished", "current_element"=>"game_state", "timer_job_id"=>nil, "clock_job_id"=>nil)
    obj.tournament_monitor_id = tournament_monitor_id_map[50000199] if tournament_monitor_id_map[50000199].present?
    obj.game_id = game_id_map[50000001] if game_id_map[50006426].present?
    data = {"innings_goal"=>20, "playera"=>{"result"=>71, "innings"=>20, "innings_list"=>[0, 3, 3, 3, 6, 0, 1, 19, 0, 1, 5, 1, 4, 1, 1, 9, 7, 5, 0, 2], "innings_redo_list"=>[0], "hs"=>19, "gd"=>"3.55", "balls_goal"=>80, "tc"=>0}, "playerb"=>{"result"=>69, "innings"=>20, "innings_list"=>[1, 0, 0, 2, 9, 0, 10, 5, 1, 8, 2, 1, 5, 1, 2, 10, 2, 6, 4, 0], "innings_redo_list"=>[], "hs"=>10, "gd"=>"3.45", "balls_goal"=>80, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>1, "Partie"=>13, "Spieler1"=>352853, "Spieler2"=>156194, "Ergebnis1"=>71, "Ergebnis2"=>69, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>19, "Höchstserie2"=>10, "Tischnummer"=>1}}
    obj.data = data
    created_at = Time.at(1631196877.8120818)
    updated_at = Time.at(1631377554.936971)
    begin
      obj.save!
      id = obj.id
      table_monitor_id_map[50000001] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    table_monitor_id_map[50000001] = id
  end
end
created_at = Time.at(1631196877.900341)
updated_at = Time.at(1631377410.486722)
timer_start_at = Time.at(1631376950.854314)
timer_finish_at = Time.at(1631377250.854319)
obj_was = TableMonitor.where("id"=>50000002, "tournament_monitor_id"=>50000199, "state"=>"game_result_reported", "name"=>"Tisch 6", "game_id"=>50006439, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>"timeout", "nnn"=>nil, "panel_state"=>"game_finished", "current_element"=>"game_state", "timer_job_id"=>nil, "clock_job_id"=>nil, created_at: created_at, updated_at: updated_at, timer_start_at: timer_start_at, timer_finish_at: timer_finish_at).first
if obj_was.blank?
  obj_was = TableMonitor.where("tournament_monitor_id"=>50000199, "state"=>"game_result_reported", "name"=>"Tisch 6", "game_id"=>50006439, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>"timeout", "nnn"=>nil, "panel_state"=>"game_finished", "current_element"=>"game_state", "timer_job_id"=>nil, "clock_job_id"=>nil).first
  if obj_was.blank?
    obj = TableMonitor.new("tournament_monitor_id"=>50000199, "state"=>"game_result_reported", "name"=>"Tisch 6", "game_id"=>50006439, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>"timeout", "nnn"=>nil, "panel_state"=>"game_finished", "current_element"=>"game_state", "timer_job_id"=>nil, "clock_job_id"=>nil)
    obj.tournament_monitor_id = tournament_monitor_id_map[50000199] if tournament_monitor_id_map[50000199].present?
    obj.game_id = game_id_map[50000002] if game_id_map[50006439].present?
    data = {"innings_goal"=>20, "timeouts"=>0, "timeout"=>0, "playera"=>{"result"=>75, "innings"=>20, "innings_list"=>[16, 5, 1, 8, 1, 0, 3, 4, 7, 2, 1, 14, 3, 1, 0, 5, 3, 0, 1, 0], "innings_redo_list"=>[0], "hs"=>16, "gd"=>"3.75", "balls_goal"=>80, "tc"=>0}, "playerb"=>{"result"=>65, "innings"=>20, "innings_list"=>[2, 3, 5, 12, 2, 0, 6, 0, 2, 3, 15, 0, 0, 2, 0, 1, 3, 3, 6, 0], "innings_redo_list"=>[], "hs"=>15, "gd"=>"3.25", "balls_goal"=>80, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>1, "Partie"=>14, "Spieler1"=>352025, "Spieler2"=>121340, "Ergebnis1"=>75, "Ergebnis2"=>65, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>16, "Höchstserie2"=>15, "Tischnummer"=>2}}
    obj.data = data
    created_at = Time.at(1631196877.900341)
    updated_at = Time.at(1631377410.486722)
    timer_start_at = Time.at(1631376950.854314)
    timer_finish_at = Time.at(1631377250.854319)
    begin
      obj.save!
      id = obj.id
      table_monitor_id_map[50000002] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
      obj.update_column(:"timer_start_at", timer_start_at)
      obj.update_column(:"timer_finish_at", timer_finish_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    table_monitor_id_map[50000002] = id
  end
end
created_at = Time.at(1631196877.9649222)
updated_at = Time.at(1631376204.311699)
obj_was = TableMonitor.where("id"=>50000003, "tournament_monitor_id"=>50000199, "state"=>"game_result_reported", "name"=>"Tisch 7", "game_id"=>50006436, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"game_finished", "current_element"=>"game_state", "timer_job_id"=>nil, "clock_job_id"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = TableMonitor.where("tournament_monitor_id"=>50000199, "state"=>"game_result_reported", "name"=>"Tisch 7", "game_id"=>50006436, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"game_finished", "current_element"=>"game_state", "timer_job_id"=>nil, "clock_job_id"=>nil).first
  if obj_was.blank?
    obj = TableMonitor.new("tournament_monitor_id"=>50000199, "state"=>"game_result_reported", "name"=>"Tisch 7", "game_id"=>50006436, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"game_finished", "current_element"=>"game_state", "timer_job_id"=>nil, "clock_job_id"=>nil)
    obj.tournament_monitor_id = tournament_monitor_id_map[50000199] if tournament_monitor_id_map[50000199].present?
    obj.game_id = game_id_map[50000003] if game_id_map[50006436].present?
    data = {"innings_goal"=>20, "playera"=>{"result"=>67, "innings"=>20, "innings_list"=>[0, 1, 2, 8, 7, 5, 8, 0, 2, 5, 1, 2, 3, 2, 2, 0, 2, 16, 1, 0], "innings_redo_list"=>[0], "hs"=>16, "gd"=>"3.35", "balls_goal"=>80, "tc"=>0}, "playerb"=>{"result"=>23, "innings"=>20, "innings_list"=>[0, 0, 3, 2, 0, 2, 3, 3, 0, 2, 0, 3, 0, 2, 0, 0, 0, 1, 1, 1], "innings_redo_list"=>[], "hs"=>3, "gd"=>"1.15", "balls_goal"=>80, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "ba_results"=>{"Gruppe"=>1, "Partie"=>15, "Spieler1"=>247211, "Spieler2"=>228105, "Ergebnis1"=>67, "Ergebnis2"=>23, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>16, "Höchstserie2"=>3, "Tischnummer"=>3}}
    obj.data = data
    created_at = Time.at(1631196877.9649222)
    updated_at = Time.at(1631376204.311699)
    begin
      obj.save!
      id = obj.id
      table_monitor_id_map[50000003] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    table_monitor_id_map[50000003] = id
  end
end
created_at = Time.at(1631196985.471492)
updated_at = Time.at(1631349669.8992121)
obj_was = TableMonitor.where("id"=>50000004, "tournament_monitor_id"=>nil, "state"=>"playing_game", "name"=>"Tisch 8", "game_id"=>50006444, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"pointer_mode", "current_element"=>"pointer_mode", "timer_job_id"=>nil, "clock_job_id"=>"0da0d9fa-8b53-4576-adb8-537ac1267ed9", created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = TableMonitor.where("tournament_monitor_id"=>nil, "state"=>"playing_game", "name"=>"Tisch 8", "game_id"=>50006444, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"pointer_mode", "current_element"=>"pointer_mode", "timer_job_id"=>nil, "clock_job_id"=>"0da0d9fa-8b53-4576-adb8-537ac1267ed9").first
  if obj_was.blank?
    obj = TableMonitor.new("tournament_monitor_id"=>nil, "state"=>"playing_game", "name"=>"Tisch 8", "game_id"=>50006444, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"pointer_mode", "current_element"=>"pointer_mode", "timer_job_id"=>nil, "clock_job_id"=>"0da0d9fa-8b53-4576-adb8-537ac1267ed9")
    obj.game_id = game_id_map[50000004] if game_id_map[50006444].present?
    data = {"innings_goal"=>"20", "playera"=>{"result"=>30, "innings"=>2, "innings_list"=>[30, 0], "innings_redo_list"=>[0], "hs"=>30, "gd"=>"15.00", "balls_goal"=>"80", "tc"=>0, "discipline"=>"Freie Partie klein"}, "playerb"=>{"result"=>9, "innings"=>2, "innings_list"=>[5, 4], "innings_redo_list"=>[], "hs"=>5, "gd"=>"4.50", "balls_goal"=>"80", "tc"=>0, "discipline"=>"Freie Partie klein"}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}, "timeouts"=>0, "timeout"=>0, "ba_results"=>{"Gruppe"=>nil, "Partie"=>nil, "Spieler1"=>121340, "Spieler2"=>nil, "Ergebnis1"=>97, "Ergebnis2"=>82, "Aufnahmen1"=>20, "Aufnahmen2"=>20, "Höchstserie1"=>21, "Höchstserie2"=>24, "Tischnummer"=>nil}}
    obj.data = data
    created_at = Time.at(1631196985.471492)
    updated_at = Time.at(1631349669.8992121)
    begin
      obj.save!
      id = obj.id
      table_monitor_id_map[50000004] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    table_monitor_id_map[50000004] = id
  end
end
created_at = Time.at(1631201154.723064)
updated_at = Time.at(1631201154.723064)
obj_was = TableMonitor.where("id"=>50000005, "tournament_monitor_id"=>nil, "state"=>"new_table_monitor", "name"=>"Tisch 1", "game_id"=>nil, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"pointer_mode", "current_element"=>"pointer_mode", "timer_job_id"=>nil, "clock_job_id"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = TableMonitor.where("tournament_monitor_id"=>nil, "state"=>"new_table_monitor", "name"=>"Tisch 1", "game_id"=>nil, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"pointer_mode", "current_element"=>"pointer_mode", "timer_job_id"=>nil, "clock_job_id"=>nil).first
  if obj_was.blank?
    obj = TableMonitor.new("tournament_monitor_id"=>nil, "state"=>"new_table_monitor", "name"=>"Tisch 1", "game_id"=>nil, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"pointer_mode", "current_element"=>"pointer_mode", "timer_job_id"=>nil, "clock_job_id"=>nil)
    created_at = Time.at(1631201154.723064)
    updated_at = Time.at(1631201154.723064)
    begin
      obj.save!
      id = obj.id
      table_monitor_id_map[50000005] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    table_monitor_id_map[50000005] = id
  end
end
created_at = Time.at(1631201154.807803)
updated_at = Time.at(1631201154.807803)
obj_was = TableMonitor.where("id"=>50000006, "tournament_monitor_id"=>nil, "state"=>"new_table_monitor", "name"=>"Tisch 2", "game_id"=>nil, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"pointer_mode", "current_element"=>"pointer_mode", "timer_job_id"=>nil, "clock_job_id"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = TableMonitor.where("tournament_monitor_id"=>nil, "state"=>"new_table_monitor", "name"=>"Tisch 2", "game_id"=>nil, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"pointer_mode", "current_element"=>"pointer_mode", "timer_job_id"=>nil, "clock_job_id"=>nil).first
  if obj_was.blank?
    obj = TableMonitor.new("tournament_monitor_id"=>nil, "state"=>"new_table_monitor", "name"=>"Tisch 2", "game_id"=>nil, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"pointer_mode", "current_element"=>"pointer_mode", "timer_job_id"=>nil, "clock_job_id"=>nil)
    created_at = Time.at(1631201154.807803)
    updated_at = Time.at(1631201154.807803)
    begin
      obj.save!
      id = obj.id
      table_monitor_id_map[50000006] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    table_monitor_id_map[50000006] = id
  end
end
created_at = Time.at(1631201154.890966)
updated_at = Time.at(1631201154.890966)
obj_was = TableMonitor.where("id"=>50000007, "tournament_monitor_id"=>nil, "state"=>"new_table_monitor", "name"=>"Tisch 3", "game_id"=>nil, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"pointer_mode", "current_element"=>"pointer_mode", "timer_job_id"=>nil, "clock_job_id"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = TableMonitor.where("tournament_monitor_id"=>nil, "state"=>"new_table_monitor", "name"=>"Tisch 3", "game_id"=>nil, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"pointer_mode", "current_element"=>"pointer_mode", "timer_job_id"=>nil, "clock_job_id"=>nil).first
  if obj_was.blank?
    obj = TableMonitor.new("tournament_monitor_id"=>nil, "state"=>"new_table_monitor", "name"=>"Tisch 3", "game_id"=>nil, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"pointer_mode", "current_element"=>"pointer_mode", "timer_job_id"=>nil, "clock_job_id"=>nil)
    created_at = Time.at(1631201154.890966)
    updated_at = Time.at(1631201154.890966)
    begin
      obj.save!
      id = obj.id
      table_monitor_id_map[50000007] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    table_monitor_id_map[50000007] = id
  end
end
created_at = Time.at(1631201154.974916)
updated_at = Time.at(1631201154.974916)
obj_was = TableMonitor.where("id"=>50000008, "tournament_monitor_id"=>nil, "state"=>"new_table_monitor", "name"=>"Tisch 4", "game_id"=>nil, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"pointer_mode", "current_element"=>"pointer_mode", "timer_job_id"=>nil, "clock_job_id"=>nil, created_at: created_at, updated_at: updated_at).first
if obj_was.blank?
  obj_was = TableMonitor.where("tournament_monitor_id"=>nil, "state"=>"new_table_monitor", "name"=>"Tisch 4", "game_id"=>nil, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"pointer_mode", "current_element"=>"pointer_mode", "timer_job_id"=>nil, "clock_job_id"=>nil).first
  if obj_was.blank?
    obj = TableMonitor.new("tournament_monitor_id"=>nil, "state"=>"new_table_monitor", "name"=>"Tisch 4", "game_id"=>nil, "next_game_id"=>nil, "ip_address"=>nil, "active_timer"=>nil, "nnn"=>nil, "panel_state"=>"pointer_mode", "current_element"=>"pointer_mode", "timer_job_id"=>nil, "clock_job_id"=>nil)
    created_at = Time.at(1631201154.974916)
    updated_at = Time.at(1631201154.974916)
    begin
      obj.save!
      id = obj.id
      table_monitor_id_map[50000008] = id
      obj.update_column(:"created_at", created_at)
      obj.update_column(:"updated_at", updated_at)
    rescue StandardError => e
    end
  else
    id = obj_was.id
    table_monitor_id_map[50000008] = id
  end
end
