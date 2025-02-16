class UpdateT14 < ActiveRecord::Migration[6.0]
  def change
    TournamentPlan.find_by_name("T14").update(executor_params: {"g1" => {"pl" => 4, "rs" => "eae_pg", "sq" => {"r1" => {"t1" => "2-3", "t2" => "1-4"}}}, "g2" => {"pl" => 4, "rs" => "eae_pg", "sq" => {"r1" => {"t3" => "2-3", "t4" => "1-4"}}}, "hf1" => {"r4" => {"t-rand-1-2" => ["g1.rk1", "g2.rk2"]}}, "hf2" => {"r4" => {"t-rand-1-2" => ["g2.rk1", "g1.rk2"]}}, "p<5-8>1" => {"r4" => {"t-rand-3-4" => ["g2.rk3", "g1.rk4"]}}, "p<5-8>2" => {"r4" => {"t-rand-3-4" => ["g1.rk3", "g2.rk4"]}}, "fin" => {"r5" => {"t-admin-1-4" => ["hf1.rk1", "hf2.rk1"]}}, "p<3-4>" => {"r5" => {"t-admin-1-4" => ["hf1.rk2", "hf2.rk2"]}}, "p<5-6>" => {"r5" => {"t-admin-1-4" => ["p<5-8>1.rk1", "p<5-8>2.rk1"]}}, "p<7-8>" => {"r5" => {"t-admin-1-4" => ["p<5-8>1.rk2", "p<5-8>2.rk2"]}}, "RK" => ["fin.rk1", "fin.rk2", "p<3-4>.rk1", "p<3-4>.rk2", "p<5-6>.rk1", "p<5-6>.rk2", "p<7-8>.rk1", "p<7-8>.rk2"]}.to_json)
  end
end
