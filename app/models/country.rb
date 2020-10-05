class Country < ActiveRecord::Base
  has_many :regions

  COLUMN_NAMES = {        #TODO FILTERS
                          "Name" => "countries.name",
                          "Code" => "countries.code"
  }
end
