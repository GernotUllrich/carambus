class UpdatePlansGk < ActiveRecord::Migration[6.0]
  def change
    TournamentPlan.find_by_name("T18").update(executor_params:
                                                { "GK" => 27,
                                                  "g1" =>
                                                    { "pl" => 5,
                                                      "rs" => "eae",
                                                      "sq" =>
                                                        { "r1" => { "t1" => "3-4", "t2" => "2-5" },
                                                          "r2" => { "t1" => "1-5", "t2" => "2-4" },
                                                          "r3" => { "t1" => "4-5", "t2" => "1-3" },
                                                          "r4" => { "t1" => "2-3", "t2" => "1-4" },
                                                          "r5" => { "t1" => "1-2", "t2" => "3-5" } } },
                                                  "g2" =>
                                                    { "pl" => 5,
                                                      "rs" => "eae",
                                                      "sq" =>
                                                        { "r1" => { "t3" => "3-4", "t4" => "2-5" },
                                                          "r2" => { "t3" => "1-5", "t4" => "2-4" },
                                                          "r3" => { "t3" => "4-5", "t4" => "1-3" },
                                                          "r4" => { "t3" => "2-3", "t4" => "1-4" },
                                                          "r5" => { "t3" => "1-2", "t4" => "3-5" } } },
                                                  "hf1" => { "r6" => { "t-rand-1-2" => ["g1.rk1", "g2.rk2"] } },
                                                  "hf2" => { "r6" => { "t-rand-1-2" => ["g2.rk1", "g1.rk2"] } },
                                                  "p<9-10>" => { "r6" => { "t-rand-3-4" => ["g1.rk5", "g2.rk5"] } },
                                                  "p<7-8>" => { "r6" => { "t-rand-3-4" => ["g1.rk4", "g2.rk4"] } },
                                                  "p<5-6>" => { "r7" => { "t-admin-1-3" => ["g1.rk3", "g2.rk3"] } },
                                                  "fin" => { "r7" => { "t-admin-1-3" => ["hf1.rk1", "hf2.rk1"] } },
                                                  "p<3-4>" => { "r7" => { "t-admin-1-3" => ["hf1.rk2", "hf2.rk2"] } },
                                                  "RK" => ["fin.rk1", "fin.rk2", "p<3-4>.rk1", "p<3-4>.rk2", "p<5-6>.rk1", "p<5-6>.rk2", "p<7-8>.rk1", "p<7-8>.rk2", "p<9-10>.rk1", "p<9-10>.rk2"] }.to_json)
    TournamentPlan.find_by_name("T19").update(executor_params:
                                                { "GK" => 27,
                                                  "g1" =>
                                                    { "pl" => 5,
                                                      "rs" => "eae",
                                                      "sc" => { "d1" => ["rd1", "rd2", "rd3", "rd4"], "d2" => ["rd5", "rd6", "rd7"] },
                                                      "sq" =>
                                                        { "r1" => { "t1" => "3-4", "t2" => "2-5" },
                                                          "r2" => { "t1" => "1-5", "t2" => "2-4" },
                                                          "r3" => { "t1" => "4-5", "t2" => "1-3" },
                                                          "r4" => { "t1" => "2-3", "t2" => "1-4" },
                                                          "r5" => { "t1" => "1-2", "t2" => "3-5" } } },
                                                  "g2" =>
                                                    { "pl" => 5,
                                                      "rs" => "eae",
                                                      "sq" =>
                                                        { "r1" => { "t3" => "3-4", "t4" => "2-5" },
                                                          "r2" => { "t3" => "1-5", "t4" => "2-4" },
                                                          "r3" => { "t3" => "4-5", "t4" => "1-3" },
                                                          "r4" => { "t3" => "2-3", "t4" => "1-4" },
                                                          "r5" => { "t3" => "1-2", "t4" => "3-5" } } },
                                                  "hf1" => { "r6" => { "t-rand-1-2" => ["g1.rk1", "g2.rk2"] } },
                                                  "hf2" => { "r6" => { "t-rand-1-2" => ["g2.rk1", "g1.rk2"] } },
                                                  "p<9-10>" => { "r6" => { "t-rand-3-4" => ["g1.rk5", "g2.rk5"] } },
                                                  "p<7-8>" => { "r6" => { "t-rand-3-4" => ["g1.rk4", "g2.rk4"] } },
                                                  "p<5-6>" => { "r7" => { "t-admin-1-3" => ["g1.rk3", "g2.rk3"] } },
                                                  "fin" => { "r7" => { "t-admin-1-3" => ["hf1.rk1", "hf2.rk1"] } },
                                                  "p<3-4>" => { "r7" => { "t-admin-1-3" => ["hf1.rk2", "hf2.rk2"] } },
                                                  "RK" => ["fin.rk1", "fin.rk2", "p<3-4>.rk1", "p<3-4>.rk2", "p<5-6>.rk1", "p<5-6>.rk2", "p<7-8>.rk1", "p<7-8>.rk2", "p<9-10>.rk1", "p<9-10>.rk2"] }.to_json)
    TournamentPlan.find_by_name("T06").update(executor_params:
                                                { "GK" => 11,
                                                  "g1" => { "pl" => 3, "rs" => "eae", "sq" => { "r1" => { "t1" => "2-3" }, "r2" => { "t1" => "1-3" }, "r3" => { "t1" => "1-2" } } },
                                                  "g2" => { "pl" => 3, "rs" => "eae", "sq" => { "r1" => { "t2" => "2-3" }, "r2" => { "t2" => "1-3" }, "r3" => { "t2" => "1-2" } } },
                                                  "hf1" => { "r4" => { "t-rand-1-2" => ["g1.rk1", "g2.rk2"] } },
                                                  "hf2" => { "r4" => { "t-rand-1-2" => ["g2.rk1", "g1.rk2"] } },
                                                  "p<5-6>" => { "r4" => { "t3" => ["g1.rk3", "g2.rk3"] } },
                                                  "fin" => { "r5" => { "t-admin-1-3" => ["hf1.rk1", "hf2.rk1"] } },
                                                  "p<3-4>" => { "r5" => { "t-admin-1-3" => ["hf1.rk2", "hf2.rk2"] } },
                                                  "RK" => ["fin.rk1", "fin.rk2", "p<3-4>.rk1", "p<3-4>.rk2", "p<5-6>.rk1", "p<5-6>.rk2"] }.to_json)
    TournamentPlan.find_by_name("T10").update(executor_params:
                                                { "GK" => 10,
                                                  "g1" => { "pl" => 3, "rs" => "eae", "sq" => { "r1" => { "t1" => "2-3" }, "r2" => { "t1" => "1-3" }, "r3" => { "t1" => "1-2" } } },
                                                  "g2" => { "pl" => 4, "rs" => "eae_pg", "sq" => { "r1" => { "t2" => "2-3", "t3" => "1-4" } } },
                                                  "hf1" => { "r4" => { "t-admin-1-3" => ["g1.rk1", "g2.rk2"] } },
                                                  "hf2" => { "r4" => { "t-admin-1-3" => ["g2.rk1", "g1.rk2"] } },
                                                  "p<5-6>" => { "r4" => { "t-admin-1-3" => ["g1.rk3", "g2.rk3"] } },
                                                  "fin" => { "r5" => { "t-admin-1-2" => ["hf1.rk1", "hf2.rk1"] } },
                                                  "p<3-4>" => { "r5" => { "t-admin-1-2" => ["hf1.rk2", "hf2.rk2"] } },
                                                  "RK" => ["fin.rk1", "fin.rk2", "p<3-4>.rk1", "p<3-4>.rk2", "p<5-6>.rk1", "p<5-6>.rk2", "g2.rk4"] }.to_json)
    TournamentPlan.find_by_name("T14").update(executor_params:
                                                { "GK" => 12,
                                                  "g1" => { "pl" => 4, "rs" => "eae_pg", "sq" => { "r1" => { "t1" => "2-3", "t2" => "1-4" } } },
                                                  "g2" => { "pl" => 4, "rs" => "eae_pg", "sq" => { "r1" => { "t3" => "2-3", "t4" => "1-4" } } },
                                                  "hf1" => { "r2" => { "t-rand-1-2" => ["g1.rk1", "g2.rk2"] } },
                                                  "hf2" => { "r2" => { "t-rand-1-2" => ["g2.rk1", "g1.rk2"] } },
                                                  "p<5-8>1" => { "r2" => { "t-rand-3-4" => ["g2.rk3", "g1.rk4"] } },
                                                  "p<5-8>2" => { "r2" => { "t-rand-3-4" => ["g1.rk3", "g2.rk4"] } },
                                                  "fin" => { "r3" => { "t-admin-1-4" => ["hf1.rk1", "hf2.rk1"] } },
                                                  "p<3-4>" => { "r3" => { "t-admin-1-4" => ["hf1.rk2", "hf2.rk2"] } },
                                                  "p<5-6>" => { "r3" => { "t-admin-1-4" => ["p<5-8>1.rk1", "p<5-8>2.rk1"] } },
                                                  "p<7-8>" => { "r3" => { "t-admin-1-4" => ["p<5-8>1.rk2", "p<5-8>2.rk2"] } },
                                                  "RK" => ["fin.rk1", "fin.rk2", "p<3-4>.rk1", "p<3-4>.rk2", "p<5-6>.rk1", "p<5-6>.rk2", "p<7-8>.rk1", "p<7-8>.rk2"] }.to_json)
    TournamentPlan.find_by_name("T15").update(executor_params:
                                                { "GK" => 10,
                                                  "g1" => { "pl" => 4, "rs" => "eae_pg", "sq" => { "r1" => { "t1" => "1-4", "t2" => "2-3" } } },
                                                  "g2" => { "pl" => 4, "rs" => "eae_pg", "sq" => { "r1" => { "t3" => "1-4", "t4" => "2-3" } } },
                                                  "hf1" => { "r2" => { "t-rand-1-2" => ["g1.rk1", "g2.rk2"] } },
                                                  "hf2" => { "r2" => { "t-rand-1-2" => ["g2.rk1", "g1.rk2"] } },
                                                  "p<5-6>" => { "r2" => { "t-rand-3-4" => ["g1.rk3", "g2.rk3"] } },
                                                  "p<7-8>" => { "r2" => { "t-rand-3-4" => ["g1.rk4", "g2.rk4"] } },
                                                  "p<3-4>" => { "r3" => { "t-admin-1-2" => ["hf1.rk2", "hf2.rk2"] } },
                                                  "fin" => { "r3" => { "t-admin-1-2" => ["hf1.rk1", "hf2.rk1"] } },
                                                  "RK" => ["fin.rk1", "fin.rk2", "p<3-4>.rk1", "p<3-4>.rk2", "p<5-6>.rk1", "p<5-6>.rk2", "p<7-8>.rk1", "p<7-8>.rk2"] }.to_json)
    TournamentPlan.find_by_name("T16").update(executor_params:
                                                { "GK" => 16,
                                                  "g1" => { "pl" => 3, "rs" => "eae", "sq" => { "r1" => { "t1" => "1-3" }, "r2" => { "t1" => "2-3" }, "r3" => { "t1" => "1-2" } } },
                                                  "g2" => { "pl" => 3, "rs" => "eae", "sq" => { "r1" => { "t2" => "1-3" }, "r2" => { "t2" => "2-3" }, "r3" => { "t2" => "1-2" } } },
                                                  "g3" => { "pl" => 3, "rs" => "eae", "sq" => { "r1" => { "t3" => "1-3" }, "r2" => { "t3" => "2-3" }, "r3" => { "t3" => "1-2" } } },
                                                  "hf1" => { "r4" => { "t-rand-1-2" => ["(g1.rk1+g2.rk1+g3.rk1+(g1.rk2+g2.rk2+g3.rk2).rk1).rk1", "(g1.rk1+g2.rk1+g3.rk1+(g1.rk2+g2.rk2+g3.rk2).rk1).rk4"] } },
                                                  "hf2" => { "r4" => { "t-rand-1-2" => ["(g1.rk1+g2.rk1+g3.rk1+(g1.rk2+g2.rk2+g3.rk2).rk1).rk2", "(g1.rk1+g2.rk1+g3.rk1+(g1.rk2+g2.rk2+g3.rk2).rk1).rk3"] } },
                                                  "p<8-9>" => { "r4" => { "t3" => ["(g1.rk3+g2.rk3+g3.rk3).rk2", "(g1.rk3+g2.rk3+g3.rk3).rk3"] } },
                                                  "p<5-6>" => { "r4" => { "t4" => ["(g1.rk2+g2.rk2+g3.rk2).rk2", "(g1.rk2+g2.rk2+g3.rk2).rk3"] } },
                                                  "p<3-4>" => { "r5" => { "t-admin-1-3" => ["hf1.rk2", "hf2.rk2"] } },
                                                  "fin" => { "r5" => { "t-admin-1-3" => ["hf1.rk1", "hf2.rk1"] } },
                                                  "p<7-8>" => { "r5" => { "t-admin-1-3" => ["(g1.rk3+g2.rk3+g3.rk3).rk1", "p<8-9>.rk1"] } },
                                                  "RK" => ["fin.rk1", "fin.rk2", "p<3-4>.rk1", "p<3-4>.rk2", "p<5-6>.rk1", "p<5-6>.rk2", "p<7-8>.rk1", "p<8-9>.rk1", "p<8-9>.rk2"] }.to_json)
    TournamentPlan.find_by_name("T17").update(executor_params:
                                                { "GK" => 25,
                                                  "g1" =>
                                                    { "pl" => 5,
                                                      "rs" => "eae",
                                                      "sq" =>
                                                        { "r1" => { "t1" => "3-4", "t2" => "2-5" },
                                                          "r2" => { "t1" => "1-5", "t2" => "2-4" },
                                                          "r3" => { "t1" => "4-5", "t2" => "1-3" },
                                                          "r4" => { "t1" => "2-3", "t2" => "1-4" },
                                                          "r5" => { "t1" => "1-2", "t2" => "3-5" } } },
                                                  "g2" =>
                                                    { "pl" => 5,
                                                      "rs" => "eae",
                                                      "sq" =>
                                                        { "r1" => { "t3" => "3-4", "t4" => "2-5" },
                                                          "r2" => { "t3" => "1-5", "t4" => "2-4" },
                                                          "r3" => { "t3" => "4-5", "t4" => "1-3" },
                                                          "r4" => { "t3" => "2-3", "t4" => "1-4" },
                                                          "r5" => { "t3" => "1-2", "t4" => "3-5" } } },
                                                  "p<9-10>" => { "r6" => { "t-rand-1-4" => ["g1.rk5", "g2.rk5"] } },
                                                  "p<7-8>" => { "r6" => { "t-rand-1-4" => ["g1.rk4", "g2.rk4"] } },
                                                  "p<5-6>" => { "r6" => { "t-rand-1-4" => ["g1.rk3", "g2.rk3"] } },
                                                  "p<3-4>" => { "r6" => { "t-rand-1-4" => ["g1.rk2", "g2.rk2"] } },
                                                  "fin" => { "r7" => { "t-admin-1-4" => ["g1.rk1", "g1.rk1"] } },
                                                  "RK" => ["fin.rk1", "fin.rk2", "p<3-4>.rk1", "p<3-4>.rk2", "p<5-6>.rk1", "p<5-6>.rk2", "p<7-8>.rk1", "p<7-8>.rk2", "p<9-10>.rk1", "p<9-10>.rk2"] }.to_json)
    TournamentPlan.find_by_name("T23").update(executor_params:
                                                { "GK" => 22,
                                                  "g1" => { "pl" => 3, "rs" => "eae", "sq" => { "r1" => { "t1" => "1-3" }, "r2" => { "t3" => "2-3" }, "r3" => { "t2" => "1-2" } } },
                                                  "g2" => { "pl" => 4, "rs" => "eae", "sq" => { "r1" => { "t3" => "1-4" }, "r2" => { "t2" => "2-3" }, "r3" => { "t1" => "1-3", "t3" => "2-4" }, "r4" => { "t1" => "3-4", "t2" => "1-2" } } },
                                                  "g3" => { "pl" => 4, "rs" => "eae", "sq" => { "r1" => { "t2" => "1-4", "t4" => "2-3" }, "r2" => { "t1" => "2-4", "t4" => "1-3" }, "r3" => { "t2" => "1-2" }, "r4" => { "t1" => "3-4" } } },
                                                  "p<9-10>" => { "r5" => { "t-rand-1-4" => ["(g2.rk4 + g3.rk4).rk1", "(g1.rk3 + g2.rk3 + g3.rk3).rk3"] } },
                                                  "p<7-8>" => { "r5" => { "t-rand-1-4" => ["(g1.rk3 + g2.rk3 + g3.rk3).rk1", "(g1.rk3 + g2.rk3 + g3.rk3).rk2"] } },
                                                  "hf1" => { "r5" => { "t-rand-1-4" => ["(g1.rk2 + g2.rk2 + g3.rk2).rk1", "(g1.rk1 + g2.rk1 + g3.rk1).rk1"] } },
                                                  "hf2" => { "r5" => { "t-rand-1-4" => ["(g1.rk1 + g2.rk1 + g3.rk1).rk2", "(g1.rk1 + g2.rk1 + g3.rk1).rk3"] } },
                                                  "p<5-6>" => { "r6" => { "t-admin-1-4" => ["(g1.rk2 + g2.rk2 + g3.rk2).rk2", "(g1.rk2 + g2.rk2 + g3.rk2).rk3"] } },
                                                  "p<3-4>" => { "r6" => { "t-admin-1-4" => ["hf1.rk2", "hf2.rk2"] } },
                                                  "fin" => { "r6" => { "t-admin-1-4" => ["hf1.rk1", "hf2.rk1"] } },
                                                  "RK" =>
                                                    ["fin.rk1",
                                                     "fin.rk2",
                                                     "p<3-4>.rk1",
                                                     "p<3-4>.rk2",
                                                     "p<5-6>.rk1",
                                                     "p<5-6>.rk2",
                                                     "p<7-8>.rk1",
                                                     "p<7-8>.rk2",
                                                     "p<9-10>.rk1",
                                                     "p<9-10>.rk2",
                                                     "(g2.rk4 + g3.rk4).rk2"] }.to_json)
    TournamentPlan.find_by_name("T24").update(executor_params:
                                                { "GK" => 26,
                                                  "g1" => { "pl" => 4, "rs" => "eae", "sq" => { "r1" => { "t1" => "1-4", "t2" => "2-3" }, "r2" => { "t3" => "1-3" }, "r3" => { "t4" => "2-4" }, "r4" => { "t1" => "3-4" }, "r5" => { "t2" => "1-2" } } },
                                                  "g2" => { "pl" => 4, "rs" => "eae", "sq" => { "r1" => { "t3" => "1-4" }, "r2" => { "t1" => "2-4", "t4" => "1-3" }, "r3" => { "t2" => "2-3" }, "r4" => { "t3" => "3-4" }, "r5" => { "t1" => "1-2" } } },
                                                  "g3" => { "pl" => 4, "rs" => "eae", "sq" => { "r1" => { "t4" => "1-4" }, "r2" => { "t2" => "2-3" }, "r3" => { "t1" => "1-3", "t3" => "2-4" }, "r4" => { "t2" => "3-4" }, "r5" => { "t3" => "1-2" } } },
                                                  "p<11-12" => { "r6" => { "t-rand-1-4" => ["(g1.rk4 + g2.rk4 +g3.rk4).rk2", "(g1.rk4 + g2.rk4 +g3.rk4).rk3"] } },
                                                  "p<9-10" => { "r6" => { "t-rand-1-4" => ["(g1.rk4 + g2.rk4 +g3.rk4).rk1", "(g1.rk3 + g2.rk3 +g3.rk3).rk3"] } },
                                                  "hf1" => { "r6" => { "t-rand-1-4" => ["(g1.rk2 + g2.rk2 +g3.rk2).rk1", "(g1.rk1 + g2.rk1 +g3.rk1).rk1"] } },
                                                  "hf2" => { "r6" => { "t-rand-1-4" => ["(g1.rk1 + g2.rk1 +g3.rk1).rk2", "(g1.rk1 + g2.rk1 +g3.rk1).rk3"] } },
                                                  "p<7-8>" => { "r7" => { "t-admin-1-4" => ["(g1.rk3 + g2.rk3 +g3.rk3).rk1", "(g1.rk3 + g2.rk3 +g3.rk3).rk2"] } },
                                                  "p<5-6>" => { "r7" => { "t-admin-1-4" => ["(g1.rk2 + g2.rk2 +g3.rk2).rk2", "(g1.rk2 + g2.rk2 +g3.rk2).rk3"] } },
                                                  "p<3-4>" => { "r7" => { "t-admin-1-4" => ["hf1.rk2", "hf2.rk2"] } },
                                                  "fin" => { "r7" => { "t-admin-1-4" => ["hf1.rk1", "hf2.rk1"] } },
                                                  "RK" =>
                                                    ["fin.rk1",
                                                     "fin.rk2",
                                                     "p<3-4>.rk1",
                                                     "p<3-4>.rk2",
                                                     "p<5-6>.rk1",
                                                     "p<5-6>.rk2",
                                                     "p<7-8>.rk1",
                                                     "p<7-8>.rk2",
                                                     "p<9-10>.rk1",
                                                     "p<9-10>.rk2",
                                                     "p<11-12>.rk1",
                                                     "p<11-12>.rk2"] }.to_json)
    TournamentPlan.find_by_name("T25").update(executor_params:
                                                { "GK" => 23,
                                                  "g1" => { "pl" => 4, "rs" => "eae", "sq" => { "r1" => { "t1" => "1-4", "t2" => "2-3" }, "r2" => { "t1" => "1-3", "t2" => "2-4" }, "r3" => { "t1" => "1-2", "t2" => "3-4" } } },
                                                  "g2" => { "pl" => 3, "rs" => "eae", "sq" => { "r1" => { "t3" => "1-3" }, "r2" => { "t4" => "2-3" }, "r4" => { "t1" => "1-2" } } },
                                                  "g3" => { "pl" => 3, "rs" => "eae", "sq" => { "r1" => { "t4" => "1-3" }, "r3" => { "t3" => "2-3" }, "r4" => { "t2" => "1-2" } } },
                                                  "g4" => { "pl" => 3, "rs" => "eae", "sq" => { "r2" => { "t3" => "1-3" }, "r3" => { "t4" => "2-3" }, "r4" => { "t3" => "1-2" } } },
                                                  "p<11-12>" => { "r5" => { "t-rand-1-4" => ["(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk3", "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk4"] } },
                                                  "p<9-10>" => { "r5" => { "t-rand-1-4" => ["(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk1", "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk2"] } },
                                                  "hf1" => { "r5" => { "t-rand-1-4" => ["(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk1", "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk4"] } },
                                                  "hf2" => { "r5" => { "t-rand-1-4" => ["(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk2", "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk3"] } },
                                                  "p<7-8>" => { "r6" => { "t-rand-1-4" => ["(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk3", "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk4"] } },
                                                  "p<5-6>" => { "r6" => { "t-rand-1-4" => ["(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk1", "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk2"] } },
                                                  "p<3-4>" => { "r6" => { "t-admin-1-4" => ["hf1.rk2", "hf2.rk2"] } },
                                                  "fin" => { "r6" => { "t-admin-1-4" => ["hf1.rk1", "hf2.rk1"] } },
                                                  "RK" =>
                                                    ["fin.rk1",
                                                     "fin.rk2",
                                                     "p<3-4>.rk1",
                                                     "p<3-4>.rk2",
                                                     "p<5-6>.rk1",
                                                     "p<5-6>.rk2",
                                                     "p<7-8>.rk1",
                                                     "p<7-8>.rk2",
                                                     "p<9-10>.rk1",
                                                     "p<9-10>.rk2",
                                                     "p<11-12>.rk1",
                                                     "p<11-12>.rk2",
                                                     "g1.rk4"] }.to_json)
    TournamentPlan.find_by_name("T26").update(executor_params:
                                                { "GK" => 26,
                                                  "g1" => { "pl" => 4, "rs" => "eae", "sq" => { "r1" => { "t1" => "1-4" }, "r2" => { "t1" => "2-3" }, "r3" => { "t1" => "1-3" }, "r4" => { "t1" => "3-4", "t3" => "1-2" }, "r5" => { "t1" => "2-4" } } },
                                                  "g2" => { "pl" => 4, "rs" => "eae", "sq" => { "r1" => { "t2" => "1-4" }, "r2" => { "t2" => "2-3" }, "r3" => { "t2" => "1-3" }, "r4" => { "t2" => "3-4", "t4" => "1-2" }, "r5" => { "t2" => "2-4" } } },
                                                  "g3" => { "pl" => 3, "rs" => "eae", "sq" => { "r1" => { "t3" => "1-3" }, "r2" => { "t3" => "2-3" }, "r3" => { "t3" => "1-2" } } },
                                                  "g4" => { "pl" => 3, "rs" => "eae", "sq" => { "r1" => { "t4" => "1-3" }, "r2" => { "t4" => "2-3" }, "r3" => { "t4" => "1-2" } } },
                                                  "p<11-12>" => { "r6" => { "t-rand-1-4" => ["(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk3", "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk4"] } },
                                                  "p<9-10>" => { "r6" => { "t-rand-1-4" => ["(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk1", "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk2"] } },
                                                  "hf1" => { "r6" => { "t-rand-1-4" => ["(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk1", "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk4"] } },
                                                  "hf2" => { "r6" => { "t-rand-1-4" => ["(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk2", "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk3"] } },
                                                  "p<7-8>" => { "r7" => { "t-rand-1-4" => ["(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk3", "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk4"] } },
                                                  "p<5-6>" => { "r7" => { "t-rand-1-4" => ["(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk1", "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk2"] } },
                                                  "p<3-4>" => { "r7" => { "t-admin-1-4" => ["hf1.rk2", "hf2.rk2"] } },
                                                  "fin" => { "r7" => { "t-admin-1-4" => ["hf1.rk1", "hf2.rk1"] } },
                                                  "RK" =>
                                                    ["fin.rk1",
                                                     "fin.rk2",
                                                     "p<3-4>.rk1",
                                                     "p<3-4>.rk2",
                                                     "p<5-6>.rk1",
                                                     "p<5-6>.rk2",
                                                     "p<7-8>.rk1",
                                                     "p<7-8>.rk2",
                                                     "p<9-10>.rk1",
                                                     "p<9-10>.rk2",
                                                     "p<11-12>.rk1",
                                                     "p<11-12>.rk2",
                                                     "g1.rk4",
                                                     "g2.rk4"] }.to_json)
    TournamentPlan.find_by_name("T27").update(executor_params:
                                                { "GK" => 29,
                                                  "g1" => { "pl" => 4, "rs" => "eae", "sq" => { "r1" => { "t1" => "1-4" }, "r2" => { "t1" => "2-3" }, "r3" => { "t1" => "1-3" }, "r4" => { "t1" => "2-4" }, "r5" => { "t1" => "1-2", "t2" => "3-4" } } },
                                                  "g2" => { "pl" => 4, "rs" => "eae", "sq" => { "r1" => { "t2" => "1-4" }, "r2" => { "t2" => "2-3" }, "r3" => { "t2" => "1-3" }, "r4" => { "t2" => "2-4" }, "r5" => { "t3" => "3-4", "t4" => "1-2" } } },
                                                  "g3" => { "pl" => 4, "rs" => "eae", "sq" => { "r1" => { "t3" => "1-4" }, "r2" => { "t3" => "2-3" }, "r3" => { "t3" => "1-3" }, "r4" => { "t3" => "3-4", "t4" => "1-2" }, "r6" => { "t1" => "2-4" } } },
                                                  "g4" => { "pl" => 3, "rs" => "eae", "sq" => { "r1" => { "t4" => "1-3" }, "r2" => { "t4" => "2-3" }, "r3" => { "t4" => "1-2" } } },
                                                  "p<11-12>" => { "r6" => { "t-rand-1-4" => ["(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk3", "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk4"] } },
                                                  "p<9-10>" => { "r6" => { "t-rand-1-4" => ["(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk1", "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk2"] } },
                                                  "hf1" => { "r6" => { "t-rand-1-4" => ["(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk1", "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk4"] } },
                                                  "hf2" => { "r6" => { "t-rand-1-4" => ["(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk2", "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk3"] } },
                                                  "p<7-8>" => { "r7" => { "t-rand-1-4" => ["(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk3", "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk4"] } },
                                                  "p<5-6>" => { "r7" => { "t-rand-1-4" => ["(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk1", "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk2"] } },
                                                  "p<3-4>" => { "r7" => { "t-admin-1-4" => ["hf1.rk2", "hf2.rk2"] } },
                                                  "fin" => { "r7" => { "t-admin-1-4" => ["hf1.rk1", "hf2.rk1"] } },
                                                  "RK" =>
                                                    ["fin.rk1",
                                                     "fin.rk2",
                                                     "p<3-4>.rk1",
                                                     "p<3-4>.rk2",
                                                     "p<5-6>.rk1",
                                                     "p<5-6>.rk2",
                                                     "p<7-8>.rk1",
                                                     "p<7-8>.rk2",
                                                     "p<9-10>.rk1",
                                                     "p<9-10>.rk2",
                                                     "p<11-12>.rk1",
                                                     "p<11-12>.rk2",
                                                     "g1.rk4",
                                                     "g2.rk4",
                                                     "g3.rk4"] }.to_json)
    TournamentPlan.find_by_name("T28").update(executor_params:
                                                { "GK" => 32,
                                                  "g1" =>
                                                    { "pl" => 4, "rs" => "eae", "sq" => { "r1" => { "t1" => "1-4" }, "r2" => { "t1" => "2-3" }, "r3" => { "t1" => "1-3" }, "r4" => { "t1" => "3-4" }, "r5" => { "t1" => "2-4" }, "r6" => { "t1" => "1-2" } } },
                                                  "g2" =>
                                                    { "pl" => 4, "rs" => "eae", "sq" => { "r1" => { "t2" => "1-4" }, "r2" => { "t2" => "2-3" }, "r3" => { "t2" => "1-3" }, "r4" => { "t2" => "3-4" }, "r5" => { "t2" => "2-4" }, "r6" => { "t2" => "1-2" } } },
                                                  "g3" =>
                                                    { "pl" => 4, "rs" => "eae", "sq" => { "r1" => { "t3" => "1-4" }, "r2" => { "t3" => "2-3" }, "r3" => { "t3" => "1-3" }, "r4" => { "t3" => "3-4" }, "r5" => { "t3" => "2-4" }, "r6" => { "t3" => "1-2" } } },
                                                  "g4" =>
                                                    { "pl" => 4, "rs" => "eae", "sq" => { "r1" => { "t4" => "1-4" }, "r2" => { "t4" => "2-3" }, "r3" => { "t4" => "1-3" }, "r4" => { "t4" => "3-4" }, "r5" => { "t4" => "2-4" }, "r6" => { "t4" => "1-2" } } },
                                                  "p<11-12>" => { "r7" => { "t-rand-1-4" => ["(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk3", "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk4"] } },
                                                  "p<9-10>" => { "r7" => { "t-rand-1-4" => ["(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk1", "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk2"] } },
                                                  "hf1" => { "r7" => { "t-rand-1-4" => ["(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk1", "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk4"] } },
                                                  "hf2" => { "r7" => { "t-rand-1-4" => ["(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk2", "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk3"] } },
                                                  "p<7-8>" => { "r8" => { "t-rand-1-4" => ["(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk3", "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk4"] } },
                                                  "p<5-6>" => { "r8" => { "t-rand-1-4" => ["(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk1", "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk2"] } },
                                                  "p<3-4>" => { "r8" => { "t-admin-1-4" => ["hf1.rk2", "hf2.rk2"] } },
                                                  "fin" => { "r8" => { "t-admin-1-4" => ["hf1.rk1", "hf2.rk1"] } },
                                                  "RK" =>
                                                    ["fin.rk1",
                                                     "fin.rk2",
                                                     "p<3-4>.rk1",
                                                     "p<3-4>.rk2",
                                                     "p<5-6>.rk1",
                                                     "p<5-6>.rk2",
                                                     "p<7-8>.rk1",
                                                     "p<7-8>.rk2",
                                                     "p<9-10>.rk1",
                                                     "p<9-10>.rk2",
                                                     "p<11-12>.rk1",
                                                     "p<11-12>.rk2",
                                                     "g1.rk4",
                                                     "g2.rk4",
                                                     "g3.rk4",
                                                     "g4.rk4"] }.to_json)
  end
end
