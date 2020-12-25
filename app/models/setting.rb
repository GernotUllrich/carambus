# == Schema Information
#
# Table name: settings
#
#  id            :bigint           not null, primary key
#  data          :text
#  state         :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  club_id       :integer
#  region_id     :integer
#  tournament_id :integer
#
# Foreign Keys
#
#  fk_rails_...  (club_id => clubs.id)
#  fk_rails_...  (region_id => regions.id)
#  fk_rails_...  (tournament_id => tournaments.id)
#
class Setting < ApplicationRecord
  #acts_as_singleton
  serialize :data, Hash
  attr_reader :key
  attr_reader :value
  belongs_to :region
  belongs_to :club
  belongs_to :tournament

  include AASM

  @@setting = Setting.first || Setting.create!

  aasm :column => 'state' do
    state :startup, initial: true
    state :ready
    state :maintenance
  end

  def self.instance
    ret = @@setting
    if ret.blank?
      ret = @@setting = Setting.first || Setting.new.save!
    end
    ret
  end

  def self.key_set_value(k, v)
    Setting.transaction do
      inst = Setting.instance
      hash = inst.read_attribute(:data)
      hash[k.to_s] = {v.class.name => v.is_a?(Hash) || v.is_a?(Array) ? v.to_json : v.to_s}
      inst.data_will_change!
      inst.write_attribute(:data, hash)
      inst.save!
    rescue
      return nil
    end
  end

  def self.get_keys
    Setting.instance.read_attribute(:data).keys
  end

  def self.key_delete(k)
    Setting.transaction do
      inst = Setting.instance
      hash = inst.read_attribute(:data)
      hash.delete(k.to_s)
      inst.data_will_change!
      inst.write_attribute(:data, hash)
    rescue Exception => e
      return nil
    end
  end

  def self.key_get_value(k)
    Setting.transaction do
      inst = Setting.instance
      type, val = inst.read_attribute(:data)[k.to_s].to_a.flatten
      return case type
             when "Integer"
               val.to_i
             when "Float"
               val.to_f
             when "Hash"
               JSON.parse(val)
             when "Array"
               JSON.parse(val)
             else
               val
             end
    rescue
      return nil
    end
  end
end
