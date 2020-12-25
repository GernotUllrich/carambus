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
  has_many :regions

  COLUMN_NAMES = {        #TODO FILTERS
                          "Name" => "countries.name",
                          "Code" => "countries.code"
  }
end
