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
  belongs_to :region, optional: true
  belongs_to :club, optional: true
  belongs_to :tournament, optional: true

  before_save do
    Rails.logger.info "!!!!!!!" + JSON.pretty_generate(self.attributes)
  end

  SETTING = Setting.first || Setting.create!
  MIN_ID = 50000000

  include AASM

  aasm :column => 'state' do
    state :startup, initial: true
    state :ready
    state :maintenance
  end

  def self.instance
    SETTING
  end

  def self.login
    opts = RegionCcAction.get_base_opts_from_environment
    region = Region.find_by(shortname: opts[:context].upcase)
    region_cc = region.region_cc
    args = {
      username: "gernot.ullrich@gmx.de",
      userpassword: "eb4c4d00e83946e1d874d6afa18276a2",
      call_police: 7,
      loginUser: "gernot.ullrich@gmx.de",
      userpw: "VHdku&Rc=CYvX$wg3W",
      loginButton: "ANMELDEN"
    }
    _, doc = region_cc.post_cc('checkUser', args, opts)
    session_id = doc.css("script").text.match(/PHPSESSID=([a-f0-9]+)'/)[1]
    Setting.key_set_value("session_id", session_id)
  end

  def self.logoff
    opts = RegionCcAction.get_base_opts_from_environment
    region = Region.find_by(shortname: opts[:context].upcase)
    region_cc = region.region_cc
    args = {
    }
    _, doc = region_cc.post_cc('logoff', args, opts)
    Setting.key_delete("session_id")
  end

  def self.key_set_value(k, v)
    Setting.transaction do
      inst = Setting.instance.reload
      hash = inst.data
      hash[k.to_s] = { v.class.name => v.is_a?(Hash) || v.is_a?(Array) ? v.to_json : v.to_s }
      inst.data_will_change!
      inst.update(data: hash)
    rescue
      return nil
    end
  end

  def self.get_keys
    Setting.instance.data.keys
  end

  def self.key_delete(k)
    Setting.transaction do
      inst = Setting.instance
      hash = inst.data
      hash.delete(k.to_s)
      inst.data_will_change!
      inst.update(data: hash)
    rescue StandardError => e
      return nil
    end
  end

  def self.key_get_value(k)
    Setting.transaction do
      inst = Setting.instance.reload
      hash = inst.data
      if hash[k.to_s].present?
        type, val = inst.data[k.to_s].to_a.flatten
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
      else
        if Jumpstart.config.respond_to?(k) && Jumpstart.config.send(k).present?
          v = Jumpstart.config.send(k)
          hash[k.to_s] = { v.class.name => (v.is_a?(Hash) || v.is_a?(Array)) ? v.to_json : v.to_s }
          inst.data_will_change!
          inst.update(data: hash)
          return v
        else
          return nil
        end
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
      request.body = "{\"client_id\":\"aqAJY7zNMsw0jiThccQyKOO1WyjKP0AC\",\"client_secret\":\"7PN4bsl0tikD8fylkoOY_j2RudtlayXVCI0SlPzG2Tfr7ewLUETiEYHFwVL9Rk1Q\",\"audience\":\"https://api.carambus.de\",\"grant_type\":\"client_credentials\"}"
      response = http.request(request)
      if response.message == "OK"
        resp = JSON.parse(response.read_body)
        access_token = resp["access_token"]
        token_type = resp["token_type"]
        Rails.logger.info "access_token: #{access_token} token_type: #{token_type}"

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
