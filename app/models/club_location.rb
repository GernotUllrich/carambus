# frozen_string_literal: true

# The ClubLocation model represents the many-to-many relationship
# between the Club and Location models.
# A Club can have many locations and a single Location can have many clubs.
class ClubLocation < ApplicationRecord
  include LocalProtector
  include RegionTaggable

  # Broadcast changes in realtime with Hotwire
  after_create_commit lambda {
                        broadcast_prepend_later_to :club_locations,
                                                   partial: "club_locations/index",
                                                   locals: { club_location: self }
                      }
  after_update_commit -> { broadcast_replace_later_to self }
  after_destroy_commit -> { broadcast_remove_to :club_locations, target: dom_id(self, :index) }

  belongs_to :club
  belongs_to :location

  # default status is nil - status:"closed"
end
