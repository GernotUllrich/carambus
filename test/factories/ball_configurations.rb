FactoryBot.define do
  factory :ball_configuration do
    b1_x { 0.20 }
    b1_y { 0.50 }
    b2_x { 0.50 }
    b2_y { 0.50 }
    b3_x { 0.80 }
    b3_y { 0.30 }
    table_variant { "match" }
    gather_state { "pre_gather" }
  end
end
