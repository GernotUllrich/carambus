# frozen_string_literal: true

# == Schema Information
#
# Table name: tournament_plans
#
#  id                    :bigint           not null, primary key
#  even_more_description :text
#  executor_class        :string
#  executor_params       :text
#  more_description      :text
#  name                  :string
#  ngroups               :integer
#  nrepeats              :integer
#  players               :integer
#  rulesystem            :text
#  tables                :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
class TournamentPlan < ApplicationRecord
  include LocalProtector
  has_many :discipline_tournament_plans
  has_many :tournaments

  validates :tables, presence: true

  before_save :set_paper_trail_whodunnit
  # noinspection RubyLiteralArrayInspection
  RULES = {
    T01: {
      g1: {
        pl: 2,
        rp: 3,
        rs: "eae",
        sq: {
          r1: {
            t1: "1-2/1"
          },
          r2: {
            t1: "1-2/2"
          },
          r3: {
            t1: "1-2/3"
          }
        }
      },
      RK: [
        "g1.rk1",
        "g1.rk2"
      ]
    },
    T02: {
      g1: {
        pl: 3,
        rs: "eae",
        sq: {
          r1: {
            t1: "1-3"
          },
          r2: {
            t1: "2-3"
          },
          r3: {
            t1: "1-2"
          }
        }
      },
      RK: [
        "g1.rk1",
        "g1.rk2",
        "g1.rk3"
      ]
    },
    T03: {
      g1: {
        pl: 4,
        rs: "eae_pg",
        sq: {
          r1: {
            t1: "2-3",
            t2: "1-4"
          }
        }
      },
      RK: [
        "g1.rk1",
        "g1.rk2",
        "g1.rk3",
        "g1.rk4"
      ]
    },
    M01: {
      g1: {
        pl: 12,
        sq: {
          r1: {
            "t-rand-1-4": %w[3-12 2-11 6-9 5-8]
          },
          r2: {
            "t-rand-1-4": %w[1-10 9-12 4-7 3-6]
          },
          r3: {
            "t-rand-1-4": %w[8-11 7-10 2-5 1-4]
          },
          r4: {
            "t-rand-1-3": %w[3-9 2-8 6-12]
          },
          r5: {
            "t-rand-1-3": %w[5-11 1-7 4-10]
          }
        }
      },
      RK: [
        "g1.rk1",
        "g1.rk2",
        "g1.rk3",
        "g1.rk4",
        "g1.rk5",
        "g1.rk6",
        "g1.rk7",
        "g1.rk8",
        "g1.rk9",
        "g1.rk10",
        "g1.rk11",
        "g1.rk12"
      ]
    },
    M02: {
      g1: {
        pl: 12,
        sq: {
          r1: {
            "t-rand-1-3": %w[1-4 2-8 3-12]
          },
          r2: {
            "t-rand-1-3": %w[1-7 2-11 3-6]
          },
          r3: {
            "t-rand-1-3": %w[1-10 2-5 3-9]
          },
          r4: {
            "t-rand-1-3": %w[4-7 5-11 9-12]
          },
          r5: {
            "t-rand-1-3": %w[4-10 6-9 8-11]
          },
          r6: {
            "t-rand-1-3": %w[5-8 6-12 7-10]
          }
        }
      },
      RK: [
        "g1.rk1",
        "g1.rk2",
        "g1.rk3",
        "g1.rk4",
        "g1.rk5",
        "g1.rk6",
        "g1.rk7",
        "g1.rk8",
        "g1.rk9",
        "g1.rk10",
        "g1.rk11",
        "g1.rk12"
      ]
    },
    T04: {
      g1: {
        pl: 5,
        rs: "eae",
        sq: {
          r1: {
            t1: "2-4",
            t2: "1-5"
          },
          r2: {
            t1: "1-4",
            t2: "2-3"
          },
          r3: {
            t1: "2-5",
            t2: "3-4"
          },
          r4: {
            t1: "1-3",
            t2: "4-5"
          },
          r5: {
            t1: "3-5",
            t2: "1-2"
          }
        }
      },
      RK: [
        "g1.rk1",
        "g1.rk2",
        "g1.rk3",
        "g1.rk4",
        "g1.rk5"
      ]
    },
    T05: {
      g1: {
        pl: 5,
        rs: "eae",
        sc: {
          d1: %w[
            r1
            r2
            r3
            r4
          ],
          d2: %w[
            r5
            r6
            r7
          ]
        },
        sq: {
          r1: {
            t1: "2-4",
            t2: "1-5"
          },
          r2: {
            t1: "1-4",
            t2: "2-3"
          },
          r3: {
            t1: "3-5"
          },
          r4: {
            t1: "2-5",
            t2: "3-4"
          },
          r5: {
            t1: "1-3",
            t2: "4-5"
          },
          r6: {
            t2: "1-2"
          }
        }
      },
      RK: [
        "g1.rk1",
        "g1.rk2",
        "g1.rk3",
        "g1.rk4",
        "g1.rk5"
      ]
    },
    T07: {
      g1: {
        pl: 6,
        rs: "eae",
        sq: {
          r1: {
            t1: "2-5",
            t2: "3-4",
            t3: "1-6"
          },
          r2: {
            t1: "3-6",
            t2: "1-5",
            t3: "2-4"
          },
          r3: {
            t1: "1-4",
            t2: "2-3",
            t3: "5-6"
          },
          r4: {
            t1: "4-5",
            t2: "2-6",
            t3: "1-3"
          },
          r5: {
            t1: "1-2",
            t2: "4-6",
            t3: "3-5"
          }
        }
      },
      RK: [
        "g1.rk1",
        "g1.rk2",
        "g1.rk3",
        "g1.rk4",
        "g1.rk5",
        "g1.rk6"
      ]
    },
    T08: {
      g1: {
        pl: 6,
        rs: "eae",
        sc: {
          d1: %w[
            rd1
            rd2
            rd3
          ],
          d2: %w[
            rd4
            rd5
            rd6
          ]
        },
        sq: {
          r1: {
            t1: "2-5",
            t2: "3-4",
            t3: "1-6"
          },
          r2: {
            t1: "3-6",
            t2: "1-5",
            t3: "2-4"
          },
          r3: {
            t1: "1-4",
            t2: "2-3",
            t3: "5-6"
          },
          r4: {
            t1: "4-5",
            t2: "2-6",
            t3: "1-3"
          },
          r5: {
            t1: "1-2",
            t2: "4-6",
            t3: "3-5"
          }
        }
      },
      RK: [
        "g1.rk1",
        "g1.rk2",
        "g1.rk3",
        "g1.rk4",
        "g1.rk5",
        "g1.rk6"
      ]
    },
    T00: {},
    T06: {
      g1: {
        pl: 3,
        rs: "eae",
        sq: {
          r1: {
            t1: "2-3"
          },
          r2: {
            t1: "1-3"
          },
          r3: {
            t1: "1-2"
          }
        }
      },
      g2: {
        pl: 3,
        rs: "eae",
        sq: {
          r1: {
            t2: "2-3"
          },
          r2: {
            t2: "1-3"
          },
          r3: {
            t2: "1-2"
          }
        }
      },
      hf1: {
        r4: {
          "t-rand-1-2": [
            "g1.rk1",
            "g2.rk2"
          ]
        }
      },
      hf2: {
        r4: {
          "t-rand-1-2": [
            "g2.rk1",
            "g1.rk2"
          ]
        }
      },
      "p<5-6>": {
        r4: {
          t3: [
            "g1.rk3",
            "g2.rk3"
          ]
        }
      },
      fin: {
        r5: {
          "t-admin-1-3": [
            "hf1.rk1",
            "hf2.rk1"
          ]
        }
      },
      "p<3-4>": {
        r5: {
          "t-admin-1-3": [
            "hf1.rk2",
            "hf2.rk2"
          ]
        }
      },
      RK: [
        "fin.rk1",
        "fin.rk2",
        "p<3-4>.rk1",
        "p<3-4>.rk2",
        "p<5-6>.rk1",
        "p<5-6>.rk2"
      ]
    },
    T09: {
      g1: {
        pl: 3,
        rs: "eae",
        sq: {
          r1: {
            t1: "2-3"
          },
          r2: {
            t1: "1-3"
          },
          r3: {
            t1: "1-2"
          }
        }
      },
      g2: {
        pl: 4,
        rs: "eae_pg",
        sq: {
          r1: {
            t2: "2-3",
            t3: "1-4"
          }
        }
      },
      fin: {
        r4: {
          "t-admin-1-3": [
            "g1.rk1",
            "g2.rk2"
          ]
        }
      },
      "p<3-4>": {
        r4: {
          "t-admin-1-3": [
            "g1.rk2",
            "g2.rk2"
          ]
        }
      },
      "p<5-6>": {
        r4: {
          "t-admin-1-3": [
            "g1.rk3",
            "g2.rk3"
          ]
        }
      },
      RK: ["fin.rk1",
           "fin.rk2",
           "p<3-4>.rk1",
           "p<3-4>.rk2",
           "p<5-6>.rk1",
           "p<5-6>.rk2",
           "g2.rk4"]
    },
    T10: {
      g1: {
        pl: 3,
        rs: "eae",
        sq: {
          r1: {
            t1: "2-3"
          },
          r2: {
            t1: "1-3"
          },
          r3: {
            t1: "1-2"
          }
        }
      },
      g2: {
        pl: 4,
        rs: "eae_pg",
        sq: {
          r1: {
            t2: "2-3",
            t3: "1-4"
          }
        }
      },
      hf1: {
        r4: {
          "t-admin-1-3": [
            "g1.rk1",
            "g2.rk2"
          ]
        }
      },
      hf2: {
        r4: {
          "t-admin-1-3": [
            "g2.rk1",
            "g1.rk2"
          ]
        }
      },
      "p<5-6>": {
        r4: {
          "t-admin-1-3": [
            "g1.rk3",
            "g2.rk3"
          ]
        }
      },
      fin: {
        r5: {
          "t-admin-1-2": [
            "hf1.rk1",
            "hf2.rk1"
          ]
        }
      },
      "p<3-4>": {
        r5: {
          "t-admin-1-2": [
            "hf1.rk2",
            "hf2.rk2"
          ]
        }
      },
      RK: [
        "fin.rk1",
        "fin.rk2",
        "p<3-4>.rk1",
        "p<3-4>.rk2",
        "p<5-6>.rk1",
        "p<5-6>.rk2",
        "g2.rk4"
      ]
    },
    T10F: {
      g1: {
        pl: 3,
        rs: "eae",
        sq: {
          r1: {
            t1: "2-3"
          },
          r2: {
            t1: "1-3"
          },
          r3: {
            t1: "1-2"
          }
        }
      },
      g2: {
        pl: 4,
        rs: "eae_pg",
        sq: {
          r1: {
            t2: "2-3",
            t3: "1-4"
          }
        }
      },
      hf1: {
        r4: {
          "t-rand-1-3": [
            "g1.rk1",
            "g2.rk2"
          ]
        }
      },
      hf2: {
        r4: {
          "t-rand-1-3": [
            "g2.rk1",
            "g1.rk2"
          ]
        }
      },
      "p<5-6>": {
        r4: {
          "t-rand-1-3": [
            "g1.rk3",
            "g2.rk3"
          ]
        }
      },
      fin: {
        r5: {
          "t-admin-1-2": [
            "hf1.rk1",
            "hf2.rk1"
          ]
        }
      },
      "p<3-4>": {
        r5: {
          "t-admin-1-2": [
            "hf1.rk2",
            "hf2.rk2"
          ]
        }
      },
      RK: [
        "fin.rk1",
        "fin.rk2",
        "p<3-4>.rk1",
        "p<3-4>.rk2",
        "p<5-6>.rk1",
        "p<5-6>.rk2",
        "g2.rk4"
      ]
    },
    T11: {
      g1: {
        pl: 7,
        rs: "eae",
        sc: {
          d1: %w[
            rd1
            rd2
            rd3
            rd4
          ],
          d2: %w[
            rd5
            rd6
            rd7
          ]
        },
        sq: {
          r1: {
            t1: "3-6",
            t2: "4-5",
            t3: "2-7"
          },
          r2: {
            t1: "5-6",
            t2: "4-7",
            t3: "1-3"
          },
          r3: {
            t1: "2-4",
            t2: "1-5",
            t3: "6-7"
          },
          r4: {
            t1: "1-7",
            t2: "2-6",
            t3: "3-5"
          },
          r5: {
            t1: "3-4",
            t2: "1-6",
            t3: "2-5"
          },
          r6: {
            t1: "5-7",
            t2: "2-3",
            t3: "1-4"
          },
          r7: {
            t1: "1-2",
            t2: "3-7",
            t3: "4-6"
          }
        }
      },
      RK: [
        "g1.rk1",
        "g1.rk2",
        "g1.rk3",
        "g1.rk4",
        "g1.rk5",
        "g1.rk6",
        "g1.rk7"
      ]
    },
    T12: {
      g1: {
        pl: 7,
        rs: "eae",
        sq: {
          r1: {
            t1: "3-6",
            t2: "4-5",
            t3: "2-7"
          },
          r2: {
            t1: "5-6",
            t2: "4-7",
            t3: "1-3"
          },
          r3: {
            t1: "2-4",
            t2: "1-5",
            t3: "6-7"
          },
          r4: {
            t1: "1-7",
            t2: "2-6",
            t3: "3-5"
          },
          r5: {
            t1: "3-4",
            t2: "1-6",
            t3: "2-5"
          },
          r6: {
            t1: "5-7",
            t2: "2-3",
            t3: "1-4"
          },
          r7: {
            t1: "1-2",
            t2: "3-7",
            t3: "4-6"
          }
        }
      },
      RK: [
        "g1.rk1",
        "g1.rk2",
        "g1.rk3",
        "g1.rk4",
        "g1.rk5",
        "g1.rk6",
        "g1.rk7"
      ]
    },
    T13: {
      g1: {
        pl: 4,
        rs: "eae_pg",
        sq: {
          r1: {
            t1: "2-3",
            t2: "1-4"
          }
        }
      },
      g2: {
        pl: 4,
        rs: "eae_pg",
        sq: {
          r1: {
            t3: "2-3",
            t4: "1-4"
          }
        }
      },
      fin: {
        r4: {
          "t-admin-1-4": [
            "g1.rk1",
            "g2.rk1"
          ]
        }
      },
      "p<3-4>": {
        r4: {
          "t-admin-1-4": [
            "g1.rk2",
            "g2.rk2"
          ]
        }
      },
      "p<5-6>": {
        r4: {
          "t-admin-1-4": [
            "g1.rk3",
            "g2.rk3"
          ]
        }
      },
      "p<7-8>": {
        r4: {
          "t-admin-1-4": [
            "g1.rk4",
            "g2.rk4"
          ]
        }
      },
      RK: [
        "fin.rk1",
        "fin.rk2",
        "p<3-4>.rk1",
        "p<3-4>.rk2",
        "p<5-6>.rk1",
        "p<5-6>.rk2",
        "p<7-8>.rk1",
        "p<7-8>.rk2"
      ]
    },
    T14: {
      g1: {
        pl: 4,
        rs: "eae_pg",
        sq: {
          r1: {
            t1: "2-3",
            t2: "1-4"
          }
        }
      },
      g2: {
        pl: 4,
        rs: "eae_pg",
        sq: {
          r1: {
            t3: "2-3",
            t4: "1-4"
          }
        }
      },
      hf1: {
        r4: {
          "t-rand-1-2": [
            "g1.rk1",
            "g2.rk2"
          ]
        }
      },
      hf2: {
        r4: {
          "t-rand-1-2": [
            "g2.rk1",
            "g1.rk2"
          ]
        }
      },
      "p<5-8>": {
        r4: {
          "t-rand-3-4": [
            "g2.rk3",
            "g1.rk4"
          ]
        }
      },
      fin: {
        r5: {
          "t-admin-1-4": [
            "hf1.rk1",
            "hf2.rk1"
          ]
        }
      },
      "p<3-4>": {
        r5: {
          "t-admin-1-4": [
            "hf1.rk2",
            "hf2.rk2"
          ]
        }
      },
      "p<5-6>": {
        r5: {
          "t-admin-1-4": [
            "p<5-8>1.rk1",
            "p<5-8>2.rk1"
          ]
        }
      },
      "p<7-8>": {
        r5: {
          "t-admin-1-4": [
            "p<5-8>1.rk2",
            "p<5-8>2.rk2"
          ]
        }
      },
      RK: [
        "fin.rk1",
        "fin.rk2",
        "p<3-4>.rk1",
        "p<3-4>.rk2",
        "p<5-6>.rk1",
        "p<5-6>.rk2",
        "p<7-8>.rk1",
        "p<7-8>.rk2"
      ]
    },
    T15: {
      g1: {
        pl: 4,
        rs: "eae_pg",
        sq: {
          r1: {
            t1: "1-4",
            t2: "2-3"
          }
        }
      },
      g2: {
        pl: 4,
        rs: "eae_pg",
        sq: {
          r1: {
            t3: "1-4",
            t4: "2-3"
          }
        }
      },
      hf1: {
        r4: {
          "t-rand-1-2": [
            "g1.rk1",
            "g2.rk2"
          ]
        }
      },
      hf2: {
        r4: {
          "t-rand-1-2": [
            "g2.rk1",
            "g1.rk2"
          ]
        }
      },
      "p<5-6>": {
        r4: {
          "t-rand-3-4": [
            "g1.rk3",
            "g2.rk3"
          ]
        }
      },
      "p<7-8>": {
        r4: {
          "t-rand-3-4": [
            "g1.rk4",
            "g2.rk4"
          ]
        }
      },
      "p<3-4>": {
        r5: {
          "t-admin-1-2": [
            "hf1.rk2",
            "hf2.rk2"
          ]
        }
      },
      fin: {
        r5: {
          "t-admin-1-2": [
            "hf1.rk1",
            "hf2.rk1"
          ]
        }
      },
      RK: [
        "fin.rk1",
        "fin.rk2",
        "p<3-4>.rk1",
        "p<3-4>.rk2",
        "p<5-6>.rk1",
        "p<5-6>.rk2",
        "p<7-8>.rk1",
        "p<7-8>.rk2"
      ]
    },
    T16: {
      g1: {
        pl: 3,
        rs: "eae",
        sq: {
          r1: {
            t1: "1-3"
          },
          r2: {
            t1: "2-3"
          },
          r3: {
            t1: "1-2"
          }
        }
      },
      g2: {
        pl: 3,
        rs: "eae",
        sq: {
          r1: {
            t2: "1-3"
          },
          r2: {
            t2: "2-3"
          },
          r3: {
            t2: "1-2"
          }
        }
      },
      g3: {
        pl: 3,
        rs: "eae",
        sq: {
          r1: {
            t3: "1-3"
          },
          r2: {
            t3: "2-3"
          },
          r3: {
            t3: "1-2"
          }
        }
      },
      hf1: {
        r4: {
          "t-rand-1-2": [
            "(g1.rk1+g2.rk1+g3.rk1+(g1.rk2+g2.rk2+g3.rk2).rk1).rk1",
            "(g1.rk1+g2.rk1+g3.rk1+(g1.rk2+g2.rk2+g3.rk2).rk1).rk4"
          ]
        }
      },
      hf2: {
        r4: {
          "t-rand-1-2": [
            "(g1.rk1+g2.rk1+g3.rk1+(g1.rk2+g2.rk2+g3.rk2).rk1).rk2",
            "(g1.rk1+g2.rk1+g3.rk1+(g1.rk2+g2.rk2+g3.rk2).rk1).rk3"
          ]
        }
      },
      "p<8-9>": {
        r4: {
          t3: [
            "(g1.rk3+g2.rk3+g3.rk3).rk2",
            "(g1.rk3+g2.rk3+g3.rk3).rk3"
          ]
        }
      },
      "p<5-6>": {
        r4: {
          t3: [
            "(g1.rk2+g2.rk2+g3.rk2).rk2",
            "(g1.rk2+g2.rk2+g3.rk2).rk3"
          ]
        }
      },
      "p<3-4>": {
        r5: {
          "t-admin-1-3": [
            "hf1.rk2",
            "hf2.rk2"
          ]
        }
      },
      fin: {
        r5: {
          "t-admin-1-3": [
            "hf1.rk1",
            "hf2.rk1"
          ]
        }
      },
      "p<7-8>": {
        r5: {
          "t-admin-1-3": [
            "(g1.rk3+g2.rk3+g3.rk3).rk1",
            "p<8-9>.rk1"
          ]
        }
      },
      RK: [
        "fin.rk1",
        "fin.rk2",
        "p<3-4>.rk1",
        "p<3-4>.rk2",
        "p<5-6>.rk1",
        "p<5-6>.rk2",
        "p<7-8>.rk1",
        "p<8-9>.rk1",
        "p<8-9>.rk2"
      ]
    },
    T17: {},
    T18: {
      g1: {
        pl: 5,
        rs: "eae",
        sq: {
          r1: {
            t1: "3-4",
            t2: "2-5"
          },
          r2: {
            t1: "1-5",
            t2: "2-4"
          },
          r3: {
            t1: "4-5",
            t2: "1-3"
          },
          r4: {
            t1: "2-3",
            t2: "1-4"
          },
          r5: {
            t1: "1-2",
            t2: "3-5"
          }
        }
      },
      g2: {
        pl: 5,
        rs: "eae",
        sq: {
          r1: {
            t3: "3-4",
            t4: "2-5"
          },
          r2: {
            t3: "1-5",
            t4: "2-4"
          },
          r3: {
            t3: "4-5",
            t4: "1-3"
          },
          r4: {
            t3: "2-3",
            t4: "1-4"
          },
          r5: {
            t3: "1-2",
            t4: "3-5"
          }
        }
      },
      hf1: {
        r6: {
          "t-rand-1-2": [
            "g1.rk1",
            "g2.rk2"
          ]
        }
      },
      hf2: {
        r6: {
          "t-rand-1-2": [
            "g2.rk1",
            "g1.rk2"
          ]
        }
      },
      "p<9-10>": {
        r6: {
          "t-rand-3-4": [
            "g1.rk5",
            "g2.rk5"
          ]
        }
      },
      "p<7-8>": {
        r6: {
          "t-rand-3-4": [
            "g1.rk4",
            "g2.rk4"
          ]
        }
      },
      "p<5-6>": {
        r7: {
          "t-admin-1-3": [
            "g1.rk3",
            "g2.rk3"
          ]
        }
      },
      fin: {
        r7: {
          "t-admin-1-3": [
            "hf1.rk1",
            "hf2.rk1"
          ]
        }
      },
      "p<3-4>": {
        r7: {
          "t-admin-1-3": [
            "hf1.rk2",
            "hf2.rk2"
          ]
        }
      },
      RK: [
        "fin.rk1",
        "fin.rk2",
        "p<3-4>.rk1",
        "p<3-4>.rk2",
        "p<5-6>.rk1",
        "p<5-6>.rk2",
        "p<7-8>.rk1",
        "p<7-8>.rk2",
        "p<9-10>.rk1",
        "p<9-10>.rk2"
      ]
    },
    T19: {
      g1: {
        pl: 5,
        rs: "eae",
        sc: {
          d1: %w[
            rd1
            rd2
            rd3
            rd4
          ],
          d2: %w[
            rd5
            rd6
            rd7
          ]
        },
        sq: {
          r1: {
            t1: "3-4",
            t2: "2-5"
          },
          r2: {
            t1: "1-5",
            t2: "2-4"
          },
          r3: {
            t1: "4-5",
            t2: "1-3"
          },
          r4: {
            t1: "2-3",
            t2: "1-4"
          },
          r5: {
            t1: "1-2",
            t2: "3-5"
          }
        }
      },
      g2: {
        pl: 5,
        rs: "eae",
        sq: {
          r1: {
            t3: "3-4",
            t4: "2-5"
          },
          r2: {
            t3: "1-5",
            t4: "2-4"
          },
          r3: {
            t3: "4-5",
            t4: "1-3"
          },
          r4: {
            t3: "2-3",
            t4: "1-4"
          },
          r5: {
            t3: "1-2",
            t4: "3-5"
          }
        }
      },
      hf1: {
        r6: {
          "t-rand-1-2": [
            "g1.rk1",
            "g2.rk2"
          ]
        }
      },
      hf2: {
        r6: {
          "t-rand-1-2": [
            "g2.rk1",
            "g1.rk2"
          ]
        }
      },
      "p<9-10>": {
        r6: {
          "t-rand-3-4": [
            "g1.rk5",
            "g2.rk5"
          ]
        }
      },
      "p<7-8>": {
        r6: {
          "t-rand-3-4": [
            "g1.rk4",
            "g2.rk4"
          ]
        }
      },
      "p<5-6>": {
        r7: {
          "t-admin-1-3": [
            "g1.rk3",
            "g2.rk3"
          ]
        }
      },
      fin: {
        r7: {
          "t-admin-1-3": [
            "hf1.rk1",
            "hf2.rk1"
          ]
        }
      },
      "p<3-4>": {
        r7: {
          "t-admin-1-3": [
            "hf1.rk2",
            "hf2.rk2"
          ]
        }
      },
      RK: [
        "fin.rk1",
        "fin.rk2",
        "p<3-4>.rk1",
        "p<3-4>.rk2",
        "p<5-6>.rk1",
        "p<5-6>.rk2",
        "p<7-8>.rk1",
        "p<7-8>.rk2",
        "p<9-10>.rk1",
        "p<9-10>.rk2"
      ]
    },
    T20: {
      g1: {
        pl: 5,
        rs: "eae",
        sq: {
          r1: {
            t1: "3-4",
            t2: "2-5"
          },
          r2: {
            t1: "1-5",
            t2: "2-4"
          },
          r3: {
            t1: "4-5",
            t2: "1-3"
          },
          r4: {
            t1: "2-3",
            t2: "1-4"
          },
          r5: {
            t1: "1-2",
            t2: "3-5"
          }
        }
      },
      g2: {
        pl: 5,
        rs: "eae",
        sq: {
          r1: {
            t3: "3-4",
            t4: "2-5"
          },
          r2: {
            t3: "1-5",
            t4: "2-4"
          },
          r3: {
            t3: "4-5",
            t4: "1-3"
          },
          r4: {
            t3: "2-3",
            t4: "1-4"
          },
          r5: {
            t3: "1-2",
            t4: "3-5"
          }
        }
      },
      "p<9-10>": {
        r6: {
          "t-rand-1-4": [
            "g1.rk5",
            "g2.rk5"
          ]
        }
      },
      "p<7-8>": {
        r6: {
          "t-rand-1-4": [
            "g1.rk4",
            "g2.rk4"
          ]
        }
      },
      "p<5-6>": {
        r6: {
          "t-rand-1-4": [
            "g1.rk3",
            "g2.rk3"
          ]
        }
      },
      "p<3-4>": {
        r6: {
          "t-rand-1-4": [
            "g1.rk2",
            "g2.rk2"
          ]
        }
      },
      fin: {
        r7: {
          "t-admin-1-4": [
            "g1.rk1",
            "g1.rk1"
          ]
        }
      },
      RK: [
        "fin.rk1",
        "fin.rk2",
        "p<3-4>.rk1",
        "p<3-4>.rk2",
        "p<5-6>.rk1",
        "p<5-6>.rk2",
        "p<7-8>.rk1",
        "p<7-8>.rk2",
        "p<9-10>.rk1",
        "p<9-10>.rk2"
      ]
    },
    T21: {
      g1: {
        pl: 3,
        rs: "eae",
        sq: {
          r1: {
            t1: "1-3"
          },
          r2: {
            t3: "2-3"
          },
          r3: {
            t2: "1-2"
          }
        }
      },
      g2: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t3: "1-4"
          },
          r2: {
            t2: "2-3"
          },
          r3: {
            t1: "1-3",
            t3: "2-4"
          },
          r4: {
            t1: "3-4",
            t2: "1-2"
          }
        }
      },
      g3: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t2: "1-4",
            t4: "2-3"
          },
          r2: {
            t1: "2-4",
            t4: "1-3"
          },
          r3: {
            t2: "1-2"
          },
          r4: {
            t1: "3-4"
          }
        }
      },
      "p<9-10>": {
        r5: {
          "t-rand-1-4": [
            "(g2.rk4 + g3.rk4).rk1",
            "(g1.rk3 + g2.rk3 + g3.rk3).rk3"
          ]
        }
      },
      "p<7-8>": {
        r5: {
          "t-rand-1-4": [
            "(g1.rk3 + g2.rk3 + g3.rk3).rk1",
            "(g1.rk3 + g2.rk3 + g3.rk3).rk2"
          ]
        }
      },
      hf1: {
        r5: {
          "t-rand-1-4": [
            "(g1.rk2 + g2.rk2 + g3.rk2).rk1",
            "(g1.rk1 + g2.rk1 + g3.rk1).rk1"
          ]
        }
      },
      hf2: {
        r5: {
          "t-rand-1-4": [
            "(g1.rk1 + g2.rk1 + g3.rk1).rk2",
            "(g1.rk1 + g2.rk1 + g3.rk1).rk3"
          ]
        }
      },
      "p<5-6>": {
        r6: {
          "t-admin-1-4": [
            "(g1.rk2 + g2.rk2 + g3.rk2).rk2",
            "(g1.rk2 + g2.rk2 + g3.rk2).rk3"
          ]
        }
      },
      "p<3-4>": {
        r6: {
          "t-admin-1-4": [
            "hf1.rk2",
            "hf2.rk2"
          ]
        }
      },
      fin: {
        r6: {
          "t-admin-1-4": [
            "hf1.rk1",
            "hf2.rk1"
          ]
        }
      },
      RK: [
        "fin.rk1",
        "fin.rk2",
        "p<3-4>.rk1",
        "p<3-4>.rk2",
        "p<5-6>.rk1",
        "p<5-6>.rk2",
        "p<7-8>.rk1",
        "p<7-8>.rk2",
        "p<9-10>.rk1",
        "p<9-10>.rk2",
        "(g2.rk4 + g3.rk4).rk2"
      ]
    },
    T22: {},
    T23: {
      sc: {
        d1: %w[
          rd1
          rd2
          rd3
          rd4
          rd5
        ],
        d2: %w[
          rd6
          rd7
          rd8
          rd9
        ]
      },
      g1: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t1: "1-4",
            t2: "2-3"
          },
          r2: {
            t3: "1-3"
          },
          r3: {
            t4: "2-4"
          },
          r4: {
            t1: "3-4"
          },
          r5: {
            t2: "1-2"
          }
        }
      },
      g2: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t3: "1-4"
          },
          r2: {
            t1: "2-4",
            t4: "1-3"
          },
          r3: {
            t2: "2-3"
          },
          r4: {
            t3: "3-4"
          },
          r5: {
            t1: "1-2"
          }
        }
      },
      g3: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t3: "1-4"
          },
          r2: {
            t2: "2-3"
          },
          r3: {
            t1: "1-3",
            t3: "2-4"
          },
          r4: {
            t2: "3-4"
          },
          r5: {
            t3: "1-2"
          }
        }
      },
      "g<5-8>": {
        mb: "(g1.rk3+g2.rk3+g3.rk3).rk1 + (g1.rk3+g2.rk3+g3.rk3).rk2 + (g1.rk2+g2.rk2+g3.rk2).rk3 + (g1.rk2+g2.rk2+g3.rk2).rk4",
        r6: {
          "t-rand-1-2a": "1-4",
          "t-rand-1-2b": "2-3"
        },
        r8: {
          "t-rand-1-2a": "pg",
          "t-rand-1-2b": "pg"
        },
        r9: {
          "t-rand-1-2a": "rest",
          "t-rand-1-2b": "rest"
        }
      },
      "g<9-12>": {
        mb: "g1.rk4+g2.rk4+g3.rk4+(g1.rk3+g2.rk3+g3.rk3).rk3",
        r6: {
          "t-rand-3-4a": "1-4",
          "t-rand-3-4b": "2-3"
        },
        r7: {
          "t-rand-3-4a": "pg",
          "t-rand-3-4b": "pg"
        },
        r8: {
          "t-rand-3-4a": "rest",
          "t-rand-3-4b": "rest"
        },
        hf1: {
          r7: {
            "t-rand-1-4": [
              "(g1.rk2 + g2.rk2 + g3.rk2).rk1",
              "(g1.rk1 + g2.rk1 + g3.rk1).rk1"
            ]
          }
        },
        hf2: {
          r7: {
            "t-rand-1-4": [
              "(g1.rk1 + g2.rk1 + g3.rk1).rk2",
              "(g1.rk1 + g2.rk1 + g3.rk1).rk3"
            ]
          }
        },
        "p<3-4>": {
          r7: {
            "t-admin-1-4": [
              "hf1.rk2",
              "hf2.rk2"
            ]
          }
        },
        fin: {
          r9: {
            "t-admin-1-4": [
              "hf1.rk1",
              "hf2.rk1"
            ]
          }
        }
      },
      RK: [
        "fin.rk1",
        "fin.rk2",
        "p<3-4>.rk1",
        "p<3-4>.rk2",
        "p<5-8>.rk1",
        "p<5-8>.rk2",
        "p<5-8>.rk3",
        "p<5-8>.rk4",
        "p<9-12>.rk1",
        "p<9-12>.rk2",
        "p<9-12>.rk3",
        "p<9-12>.rk4"
      ]
    },
    T24: {
      g1: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t1: "1-4",
            t2: "2-3"
          },
          r2: {
            t3: "1-3"
          },
          r3: {
            t4: "2-4"
          },
          r4: {
            t1: "3-4"
          },
          r5: {
            t2: "1-2"
          }
        }
      },
      g2: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t3: "1-4"
          },
          r2: {
            t1: "2-4",
            t4: "1-3"
          },
          r3: {
            t2: "2-3"
          },
          r4: {
            t3: "3-4"
          },
          r5: {
            t1: "1-2"
          }
        }
      },
      g3: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t4: "1-4"
          },
          r2: {
            t2: "2-3"
          },
          r3: {
            t1: "1-3",
            t3: "2-4"
          },
          r4: {
            t2: "3-4"
          },
          r5: {
            t3: "1-2"
          }
        }
      },
      "p<11-12>": {
        r6: {
          "t-rand-1-4": [
            "(g1.rk4 + g2.rk4 +g3.rk4).rk2",
            "(g1.rk4 + g2.rk4 +g3.rk4).rk3"
          ]
        }
      },
      "p<9-10>": {
        r6: {
          "t-rand-1-4": [
            "(g1.rk4 + g2.rk4 +g3.rk4).rk1",
            "(g1.rk3 + g2.rk3 +g3.rk3).rk3"
          ]
        }
      },
      hf1: {
        r6: {
          "t-rand-1-4": [
            "(g1.rk2 + g2.rk2 +g3.rk2).rk1",
            "(g1.rk1 + g2.rk1 +g3.rk1).rk1"
          ]
        }
      },
      hf2: {
        r6: {
          "t-rand-1-4": [
            "(g1.rk1 + g2.rk1 +g3.rk1).rk2",
            "(g1.rk1 + g2.rk1 +g3.rk1).rk3"
          ]
        }
      },
      "p<7-8>": {
        r7: {
          "t-admin-1-4": [
            "(g1.rk3 + g2.rk3 +g3.rk3).rk1",
            "(g1.rk3 + g2.rk3 +g3.rk3).rk2"
          ]
        }
      },
      "p<5-6>": {
        r7: {
          "t-admin-1-4": [
            "(g1.rk2 + g2.rk2 +g3.rk2).rk2",
            "(g1.rk2 + g2.rk2 +g3.rk2).rk3"
          ]
        }
      },
      "p<3-4>": {
        r7: {
          "t-admin-1-4": [
            "hf1.rk2",
            "hf2.rk2"
          ]
        }
      },
      fin: {
        r7: {
          "t-admin-1-4": [
            "hf1.rk1",
            "hf2.rk1"
          ]
        }
      },
      RK: [
        "fin.rk1",
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
        "p<11-12>.rk2"
      ]
    },
    T25: {
      g1: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t1: "1-4",
            t2: "2-3"
          },
          r2: {
            t1: "1-3",
            t2: "2-4"
          },
          r3: {
            t1: "1-2",
            t2: "3-4"
          }
        }
      },
      g2: {
        pl: 3,
        rs: "eae",
        sq: {
          r1: {
            t3: "1-3"
          },
          r2: {
            t4: "2-3"
          },
          r4: {
            t1: "1-2"
          }
        }
      },
      g3: {
        pl: 3,
        rs: "eae",
        sq: {
          r1: {
            t4: "1-3"
          },
          r3: {
            t3: "2-3"
          },
          r4: {
            t2: "1-2"
          }
        }
      },
      g4: {
        pl: 3,
        rs: "eae",
        sq: {
          r2: {
            t3: "1-3"
          },
          r3: {
            t4: "2-3"
          },
          r4: {
            t3: "1-2"
          }
        }
      },
      "p<11-12>": {
        r5: {
          "t-rand-1-4": [
            "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk3",
            "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk4"
          ]
        }
      },
      "p<9-10>": {
        r5: {
          "t-rand-1-4": [
            "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk1",
            "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk2"
          ]
        }
      },
      hf1: {
        r5: {
          "t-rand-1-4": [
            "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk1",
            "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk4"
          ]
        }
      },
      hf2: {
        r5: {
          "t-rand-1-4": [
            "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk2",
            "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk3"
          ]
        }
      },
      "p<7-8>": {
        r6: {
          "t-rand-1-4": [
            "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk3",
            "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk4"
          ]
        }
      },
      "p<5-6>": {
        r6: {
          "t-rand-1-4": [
            "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk1",
            "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk2"
          ]
        }
      },
      "p<3-4>": {
        r6: {
          "t-admin-1-4": [
            "hf1.rk2",
            "hf2.rk2"
          ]
        }
      },
      fin: {
        r6: {
          "t-admin-1-4": [
            "hf1.rk1",
            "hf2.rk1"
          ]
        }
      },
      RK: [
        "fin.rk1",
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
        "g1.rk4"
      ]
    },
    T26: {
      g1: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t1: "1-4"
          },
          r2: {
            t1: "2-3"
          },
          r3: {
            t1: "1-3"
          },
          r4: {
            t1: "3-4",
            t3: "1-2"
          },
          r5: {
            t1: "2-4"
          }
        }
      },
      g2: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t2: "1-4"
          },
          r2: {
            t2: "2-3"
          },
          r3: {
            t2: "1-3"
          },
          r4: {
            t2: "3-4",
            t4: "1-2"
          },
          r5: {
            t2: "2-4"
          }
        }
      },
      g3: {
        pl: 3,
        rs: "eae",
        sq: {
          r1: {
            t3: "1-3"
          },
          r2: {
            t3: "2-3"
          },
          r3: {
            t3: "1-2"
          }
        },
        g4: {
          pl: 3,
          rs: "eae",
          sq: {
            r1: {
              t4: "1-3"
            },
            r2: {
              t4: "2-3"
            },
            r3: {
              t4: "1-2"
            }
          }
        },
        "p<11-12>": {
          r6: {
            "t-rand-1-4": [
              "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk3",
              "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk4"
            ]
          }
        },
        "p<9-10>": {
          r6: {
            "t-rand-1-4": [
              "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk1",
              "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk2"
            ]
          }
        },
        hf1: {
          r6: {
            "t-rand-1-4": [
              "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk1",
              "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk4"
            ]
          }
        },
        hf2: {
          r6: {
            "t-rand-1-4": [
              "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk2",
              "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk3"
            ]
          }
        },
        "p<7-8>": {
          r7: {
            "t-rand-1-4": [
              "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk3",
              "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk4"
            ]
          }
        },
        "p<5-6>": {
          r7: {
            "t-rand-1-4": [
              "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk1",
              "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk2"
            ]
          }
        },
        "p<3-4>": {
          r7: {
            "t-admin-1-4": [
              "hf1.rk2",
              "hf2.rk2"
            ]
          }
        },
        fin: {
          r7: {
            "t-admin-1-4": [
              "hf1.rk1",
              "hf2.rk1"
            ]
          }
        }
      },
      RK: [
        "fin.rk1",
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
        "g2.rk4"
      ]
    },
    T27: {
      g1: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t1: "1-4"
          },
          r2: {
            t1: "2-3"
          },
          r3: {
            t1: "1-3"
          },
          r4: {
            t1: "2-4"
          },
          r5: {
            t1: "1-2",
            t2: "3-4"
          }
        }
      },
      g2: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t2: "1-4"
          },
          r2: {
            t2: "2-3"
          },
          r3: {
            t2: "1-3"
          },
          r4: {
            t2: "2-4"
          },
          r5: {
            t3: "3-4",
            t4: "1-2"
          }
        }
      },
      g3: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t3: "1-4"
          },
          r2: {
            t3: "2-3"
          },
          r3: {
            t3: "1-3"
          },
          r4: {
            t3: "3-4",
            t4: "1-2"
          },
          r6: {
            t1: "2-4"
          }
        }
      },
      g4: {
        pl: 3,
        rs: "eae",
        sq: {
          r1: {
            t4: "1-3"
          },
          r2: {
            t4: "2-3"
          },
          r3: {
            t4: "1-2"
          }
        }
      },
      "p<11-12>": {
        r6: {
          "t-rand-1-4": [
            "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk3",
            "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk4"
          ]
        }
      },
      "p<9-10>": {
        r6: {
          "t-rand-1-4": [
            "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk1",
            "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk2"
          ]
        }
      },
      hf1: {
        r6: {
          "t-rand-1-4": [
            "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk1",
            "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk4"
          ]
        }
      },
      hf2: {
        r6: {
          "t-rand-1-4": [
            "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk2",
            "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk3"
          ]
        }
      },
      "p<7-8>": {
        r7: {
          "t-rand-1-4": [
            "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk3",
            "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk4"
          ]
        }
      },
      "p<5-6>": {
        r7: {
          "t-rand-1-4": [
            "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk1",
            "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk2"
          ]
        }
      },
      "p<3-4>": {
        r7: {
          "t-admin-1-4": [
            "hf1.rk2",
            "hf2.rk2"
          ]
        }
      },
      fin: {
        r7: {
          "t-admin-1-4": [
            "hf1.rk1",
            "hf2.rk1"
          ]
        }
      },
      RK: [
        "fin.rk1",
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
        "g3.rk4"
      ]
    },
    T28: {
      g1: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t1: "1-4"
          },
          r2: {
            t1: "2-3"
          },
          r3: {
            t1: "1-3"
          },
          r4: {
            t1: "3-4"
          },
          r5: {
            t1: "2-4"
          },
          r6: {
            t1: "1-2"
          }
        }
      },
      g2: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t2: "1-4"
          },
          r2: {
            t2: "2-3"
          },
          r3: {
            t2: "1-3"
          },
          r4: {
            t2: "3-4"
          },
          r5: {
            t2: "2-4"
          },
          r6: {
            t2: "1-2"
          }
        }
      },
      g3: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t3: "1-4"
          },
          r2: {
            t3: "2-3"
          },
          r3: {
            t3: "1-3"
          },
          r4: {
            t3: "3-4"
          },
          r5: {
            t3: "2-4"
          },
          r6: {
            t3: "1-2"
          }
        }
      },
      g4: {
        pl: 4,
        rs: "eae",
        sq: {
          r1: {
            t4: "1-4"
          },
          r2: {
            t4: "2-3"
          },
          r3: {
            t4: "1-3"
          },
          r4: {
            t4: "3-4"
          },
          r5: {
            t4: "2-4"
          },
          r6: {
            t4: "1-2"
          }
        }
      },
      "p<11-12>": {
        r7: {
          "t-rand-1-4": [
            "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk3",
            "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk4"
          ]
        }
      },
      "p<9-10>": {
        r7: {
          "t-rand-1-4": [
            "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk1",
            "(g1.rk3+g2.rk3+g3.rk3+r4.rk3).rk2"
          ]
        }
      },
      hf1: {
        r7: {
          "t-rand-1-4": [
            "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk1",
            "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk4"
          ]
        }
      },
      hf2: {
        r7: {
          "t-rand-1-4": [
            "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk2",
            "(g1.rk1+g2.rk1+g3.rk1+r4.rk1).rk3"
          ]
        }
      },
      "p<7-8>": {
        r8: {
          "t-rand-1-4": [
            "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk3",
            "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk4"
          ]
        }
      },
      "p<5-6>": {
        r8: {
          "t-rand-1-4": [
            "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk1",
            "(g1.rk2+g2.rk2+g3.rk2+r4.rk2).rk2"
          ]
        }
      },
      "p<3-4>": {
        r8: {
          "t-admin-1-4": [
            "hf1.rk2",
            "hf2.rk2"
          ]
        }
      },
      fin: {
        r8: {
          "t-admin-1-4": [
            "hf1.rk1",
            "hf2.rk1"
          ]
        }
      },
      RK: [
        "fin.rk1",
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
        "g4.rk4"
      ]
    },
    EK12: {
      GK: 37,
      g1: {
        pl: 6,
        rs: "eae",
        sq: {
          r1: {
            t1: "2-5",
            t2: "3-4"
          },
          r2: {
            t1: "1-6",
            t2: "2-4"
          },
          r3: {
            t1: "3-6",
            t2: "1-5"
          },
          r4: {
            t1: "1-4",
            t2: "2-3"
          },
          r5: {
            t1: "5-6",
            t2: "1-3"
          },
          r6: {
            t1: "4-5",
            t2: "2-6"
          },
          r7: {
            t1: "4-6",
            t2: "3-5"
          },
          r8: {
            t1: "1-2"
          }
        }
      },
      g2: {
        pl: 6,
        rs: "eae",
        sq: {
          r1: {
            t3: "2-5",
            t4: "3-4"
          },
          r2: {
            t3: "1-6",
            t4: "2-4"
          },
          r3: {
            t3: "3-6",
            t4: "1-5"
          },
          r4: {
            t3: "1-4",
            t4: "2-3"
          },
          r5: {
            t3: "5-6",
            t4: "1-3"
          },
          r6: {
            t3: "4-5",
            t4: "2-6"
          },
          r7: {
            t3: "4-6",
            t4: "3-5"
          },
          r8: {
            t3: "1-2"
          }
        }
      },
      vf1: {
        r9: {
          t1: [
            "g1.rk1",
            "g2.rk4"
          ]
        }
      },
      vf2: {
        r9: {
          t2: [
            "g2.rk2",
            "g1.rk3 "
          ]
        }
      },
      vf3: {
        r9: {
          t3: [
            "g1.rk2",
            "g2.rk3"
          ]
        }
      },
      vf4: {
        r9: {
          t4: [
            "g2.rk1",
            "g1.rk4"
          ]
        }
      },
      hf1: {
        r10: {
          t1: [
            "vf1.rk1",
            "vf2.rk1"
          ]
        }
      },
      hf2: {
        r10: {
          t3: [
            "vf3.rk1",
            "vf4.rk1"
          ]
        }
      },
      fin: {
        r11: {
          "t-admin-1-4": [
            "hf1.rk1",
            "hf2.rk1"
          ]
        }
      },
      RK: [
        "fin.rk1",
        "fin.rk2",
        "hf1.rk2",
        "hf2.rk2",
        "vf1.rk2",
        "vf2.rk2",
        "vf3.rk2",
        "vf4.rk2",
        "g1.rk5",
        "g2.rk5",
        "g1.rk6",
        "g2.rk6"
      ]
    }
  }.freeze

  TEST = {
    current_round: 4,
    groups: {
      group1: [
        297,
        294,
        296
      ],
      group2: [
        266,
        301,
        299,
        261
      ]
    },
    placements: {
      round1: {
        table1: 603_229,
        table2: 603_233,
        table3: 603_232
      },
      round2: {
        table1: 603_228,
        table3: 603_234,
        table2: 603_231
      },
      round3: {
        table1: 603_227,
        table3: 603_235,
        table2: 603_230
      }
    },
    rankings: {
      total: {
        "294": {
          points: 1,
          result: 22,
          innings: 40,
          hs: 20,
          bed: 1.0,
          gd: 0.55
        },
        "296": {
          points: 2,
          result: 40,
          innings: 40,
          hs: 20,
          bed: 1.0,
          gd: 1.0
        },
        "261": {
          points: 4,
          result: 74,
          innings: 60,
          hs: 20,
          bed: 1.7,
          gd: 1.23
        },
        "266": {
          points: 4,
          result: 105,
          innings: 60,
          hs: 37,
          bed: 3.25,
          gd: 1.75
        },
        "299": {
          points: 2,
          result: 60,
          innings: 60,
          hs: 20,
          bed: 1.0,
          gd: 1.0
        },
        "301": {
          points: 2,
          result: 42,
          innings: 60,
          hs: 20,
          bed: 1.0,
          gd: 0.7
        },
        "297": {
          points: 3,
          result: 45,
          innings: 40,
          hs: 22,
          bed: 1.25,
          gd: 1.12
        }
      },
      groups: {
        total: {
          "294": {
            points: 1,
            result: 22,
            innings: 40,
            hs: 20,
            bed: 1.0,
            gd: 0.55
          },
          "296": {
            points: 2,
            result: 40,
            innings: 40,
            hs: 20,
            bed: 1.0,
            gd: 1.0
          },
          "261": {
            points: 4,
            result: 74,
            innings: 60,
            hs: 20,
            bed: 1.7,
            gd: 1.23
          },
          "266": {
            points: 4,
            result: 105,
            innings: 60,
            hs: 37,
            bed: 3.25,
            gd: 1.75
          },
          "299": {
            points: 2,
            result: 60,
            innings: 60,
            hs: 20,
            bed: 1.0,
            gd: 1.0
          },
          "301": {
            points: 2,
            result: 42,
            innings: 60,
            hs: 20,
            bed: 1.0,
            gd: 0.7
          },
          "297": {
            points: 3,
            result: 45,
            innings: 40,
            hs: 22,
            bed: 1.25,
            gd: 1.12
          }
        },
        group1: {
          "294": {
            points: 1,
            result: 22,
            innings: 40,
            hs: 20,
            bed: 1.0,
            gd: 0.55
          },
          "296": {
            points: 2,
            result: 40,
            innings: 40,
            hs: 20,
            bed: 1.0,
            gd: 1.0
          },
          "297": {
            points: 3,
            result: 45,
            innings: 40,
            hs: 22,
            bed: 1.25,
            gd: 1.12
          }
        },
        group2: {
          "261": {
            points: 4,
            result: 74,
            innings: 60,
            hs: 20,
            bed: 1.7,
            gd: 1.23
          },
          "266": {
            points: 4,
            result: 105,
            innings: 60,
            hs: 37,
            bed: 3.25,
            gd: 1.75
          },
          "299": {
            points: 2,
            result: 60,
            innings: 60,
            hs: 20,
            bed: 1.0,
            gd: 1.0
          },
          "301": {
            points: 2,
            result: 42,
            innings: 60,
            hs: 20,
            bed: 1.0,
            gd: 0.7
          }
        },
        group3: {},
        group4: {},
        group5: {},
        group6: {},
        group7: {},
        group8: {}
      },
      endgames: {
        total: {},
        groups: {
          total: {},
          fg1: {},
          fg2: {},
          fg3: {},
          fg4: {}
        },
        af1: {},
        af2: {},
        af3: {},
        af4: {},
        af5: {},
        af6: {},
        af7: {},
        af8: {},
        qf1: {},
        qf2: {},
        qf3: {},
        qf4: {},
        hf1: {},
        hf2: {},
        fin: {},
        "p<3-4>": {},
        "p<5-6>": {},
        "p<7-8>": {}
      }
    }
  }.freeze

  def self.default_plan(nplayers)
    plan = TournamentPlan.find_by_name("Default#{nplayers}")
    plan ||= TournamentPlan.new(
      name: "Default#{nplayers}",
      players: nplayers
    )
    group_sizes = group_sizes_from(nplayers)
    executor_params = {}
    (0..group_sizes.length - 1).each do |gix|
      g_perms = (1..group_sizes[gix]).to_a.permutation(2).to_a.select do |v1, v2|
                  v1 < v2
                end.map { |perm| perm.join(" - ") }
      g_params = {
        pl: group_sizes[gix],
        rs: "eae_ma",
        sq: g_perms
      }
      executor_params["g#{gix + 1}"] = g_params
    end
    plan.update(
      executor_class: " ",
      executor_params: executor_params.to_json,
      ngroups: group_sizes.length,
      nrepeats: 1,
      tables: 1
    )
    plan
  end

  def self.ko_plan(nplayers)
    return nil if nplayers < 2 || nplayers > 64

    plan = TournamentPlan.find_by_name("KO_#{nplayers}")
    plan ||= TournamentPlan.new(
      name: "KO_#{nplayers}",
      players: nplayers
    )
    rk = []
    gk = 0
    games_for_level = (0..10).map { |k| 2**k }
    complete_games = games_for_level.find_all { |i| i <= nplayers }
    cl = complete_games.count - 1
    games_for_level[cl]
    seq = [[1]]
    (1..cl).each do |m|
      seq[m] = seq[m - 1].map { |k| [k, 0] }.flatten
      (2**(m - 1) + 1..2**m).to_a.reverse.each_with_index do |n, ix|
        dx = seq[m].index(ix + 1)
        seq[m][dx + 1] = n
      end
    end
    hash = {}
    (1..(cl)).to_a.reverse_each do |lev|
      games = []
      rk_sub = []
      seq[lev].each.with_index do |n, ix|
        games[ix / 2] ||= []
        # sl is seedingslist
        games[ix / 2].push(lev == cl ? "sl.rk#{n}" : rf("#{2**lev}f#{ix + 1}.rk1"))
        rk_sub.unshift(rf("#{2**lev}f#{ix + 1}.rk2")) if lev < cl
      end
      rk.unshift(rk_sub) if lev < cl
      gn = 1
      hash.merge!(games.each_with_object({}) do |a, memo|
        memo[rf("#{2**(lev - 1)}f#{gn}")] = { "r1" => { "t-rand*" => a } }
        gk += 1
        gn += 1
      end)
    end
    rk.unshift("fin.rk2")
    rk.unshift("fin.rk1")
    rk_sub = []
    ((games_for_level[cl] + 1)..nplayers).to_a.each_with_index do |r, ix|
      sq = games_for_level[cl] - ix
      dx = (seq[cl].index(sq) / 2) + 1
      dxr = seq[cl].index(sq) % 2
      repl = hash[rf("#{2**(cl - 1)}f#{dx}")]["r1"]["t-rand*"][dxr]
      hash[rf("#{2**(cl - 1)}f#{dx}")]["r1"]["t-rand*"][dxr] = rf("#{2**cl}f#{ix + 1}.rk1")
      rk_sub.push(rf("#{2**cl}f#{ix + 1}.rk2"))
      a = [repl, "sl.rk#{r}"]
      hash[rf("#{2**cl}f#{ix + 1}")] = { "r1" => { "t-rand*" => a } }
      gk += 1
    end
    rk.push(rk_sub)
    hash["GK"] = gk
    hash["RK"] = rk
    plan.update(
      executor_class: " ",
      executor_params: hash.to_json,
      ngroups: 1,
      nrepeats: 1,
      tables: 999
    )
    plan
  end

  # rule filter
  def self.rf(rule)
    rule.gsub("64", "sixfour").gsub("32", "threetwo").gsub("4f", "qf").gsub("2f", "hf").gsub("1f1", "fin").gsub("sixfour", "64").gsub(
      "threetwo", "32"
    )
  end

  def self.group_sizes_from(nplayers)
    ngroups = nplayers / 8
    ngroups += 1 if ngroups.odd?
    ngroups = 1 if ngroups.zero?
    groups = TournamentMonitor.distribute_to_group((1..nplayers).to_a, ngroups)
    (1..ngroups).to_a.map { |gix| groups["group#{gix}"].length }
  end

  def self.update_executor_params
    TournamentPlan::RULES.each_key do |k|
      tp = TournamentPlan.find_by_name(k)
      tp.update(executor_params: TournamentPlan::RULES[k].to_json)
    end
  end
end
