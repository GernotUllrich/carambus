# == Schema Information
#
# Table name: countries
#
#  id         :bigint           not null, primary key
#  code       :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_countries_on_code  (code) UNIQUE
#
class Country < ApplicationRecord
  include LocalProtector
  has_many :regions

  COLUMN_NAMES = {
    "Name" => "countries.name",
    "Code" => "countries.code"
  }
  def self.search_hash(params)
    {
      model: Country,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: "#{[params[:sSearch], params[:search]].compact.join("&")}",
      column_names: Country::COLUMN_NAMES,
      raw_sql: "(countries.name ilike :search)
 or (countries.code ilike :search)",
      joins: nil
    }
  end
end
