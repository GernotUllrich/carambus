require 'open-uri'
require 'uri'
require 'net/http'

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

  before_save do
    Rails.logger.info "!!!!!!!" + JSON.pretty_generate(self.attributes)
  end

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
      hash[k.to_s] = { v.class.name => v.is_a?(Hash) || v.is_a?(Array) ? v.to_json : v.to_s }
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

  def self.get_carambus_api_token
    expire_str = Setting.key_get_value("carambus_api_token_expire_at")
    if expire_str.blank? || Time.parse(expire_str) < Time.now
      url = URI("https://dev-r4djmvaa.eu.auth0.com/oauth/token")
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request = Net::HTTP::Post.new(url)
      request["content-type"] = 'application/json'
      request.body = "{\"client_id\":\"cCr6hh6iGG0c6518jNhrTQE2QyCpIlfU\",\"client_secret\":\"fOxSsvvc7MxRtAI2EeRi8309sycFIHEUvRQ00mY_i-vg3MJoo85Tl2AUcifM5aRQ\",\"audience\":\"https://api.carambus.de\",\"grant_type\":\"client_credentials\"}"
      response = http.request(request)
      if response.message == "OK"
        resp = JSON.parse(response.read_body)
        access_token = resp["access_token"]
        token_type = resp["token_type"]

        Setting.key_set_value("carambus_api_access_token", access_token)
        Setting.key_set_value("carambus_api_token_type", token_type)
        Setting.key_set_value("carambus_api_token_expire_at", Time.now + 36000.seconds)
      else
        return []
      end
    else
      access_token = Setting.key_get_value("carambus_api_access_token")
      token_type = Setting.key_get_value("carambus_api_token_type")
    end
    return [access_token, token_type]
  end
end
