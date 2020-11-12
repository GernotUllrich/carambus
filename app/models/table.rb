class Table < ActiveRecord::Base
  belongs_to :location
  belongs_to :table_kind
  has_many :tournament_tables
end
