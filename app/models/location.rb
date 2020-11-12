class Location < ActiveRecord::Base
  belongs_to :club
  has_many :tables
  serialize :data, Hash
end
