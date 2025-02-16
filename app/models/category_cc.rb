# == Schema Information
#
# Table name: category_ccs
#
#  id           :bigint           not null, primary key
#  context      :string
#  max_age      :integer
#  min_age      :integer
#  name         :string
#  sex          :string
#  status       :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  branch_cc_id :integer
#  cc_id        :integer
#
class CategoryCc < ApplicationRecord
  include LocalProtector
  SEX_MAP = {
    M: "männlich",
    F: "weiblich",
    U: "unisex"
  }
  SEX_MAP_REVERSE = {
    "männlich" => "M",
    "weiblich" => "F",
    "unisex (beide Geschlechter)" => "U"
  }
  has_many :registration_list_ccs
  has_many :tournament_ccs
  belongs_to :branch_cc

  def self.search_hash(params)
    {
      model: CategoryCc,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: "#{[params[:sSearch], params[:search]].compact.join("&")}",
      column_names: [],
      raw_sql: "",
      joins: nil
    }
  end
end
