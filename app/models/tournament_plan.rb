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

  COLUMN_NAMES = { # TODO: FILTERS
                   "ID" => "tournament_plans.id",
                   "Name" => "tournament_plans.name",
                   "Rulesystem" => "tournament_plans.rulesystem",
  }.freeze

  def self.search_hash(params)
    {
      model: TournamentPlan,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: [params[:sSearch], params[:search]].compact.join("&").to_s,
      column_names: TournamentPlan::COLUMN_NAMES,
      raw_sql: "(tournament_plans.id = :isearch)
or (tournament_plans.name ilike :search)
or (tournament_plans.rulesystem ilike :search)",
      joins: []
    }
  end

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
end
