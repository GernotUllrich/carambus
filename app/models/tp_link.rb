# frozen_string_literal: true

# implement communication with tp-link switches
module TpLink
  VERSION = 0.4
  COMMANDS = { "info" => '{"system":{"get_sysinfo":{}}}',
               "on" => '{"system":{"set_relay_state":{"state":1}}}',
               "off" => '{"system":{"set_relay_state":{"state":0}}}',
               "ledoff" => '{"system":{"set_led_off":{"off":1}}}',
               "ledon" => '{"system":{"set_led_off":{"off":0}}}',
               "cloudinfo" => '{"cnCloud":{"get_info":{}}}',
               "wlanscan" => '{"netif":{"get_scaninfo":{"refresh":0}}}',
               "time" => '{"time":{"get_time":{}}}',
               "schedule" => '{"schedule":{"get_rules":{}}}',
               "countdown" => '{"count_down":{"get_rules":{}}}',
               "antitheft" => '{"anti_theft":{"get_rules":{}}}',
               "reboot" => '{"system":{"reboot":{"delay":1}}}',
               "reset" => '{"system":{"reset":{"delay":1}}}',
               "energy" => '{"emeter":{"get_realtime":{}}}' }.freeze

  extend ActiveSupport::Concern
  included do
    require "socket"
    require "timeout"
  end
  # Send command and receive reply
  # will always return a JSON
  def send_tp_link(ip, cmd, retry_count = 0)
    port = 9999
    timeout_i = 2
    sock_tcp = nil
    Timeout.timeout(timeout_i) do
      sock_tcp = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      sock_tcp.connect(Socket.pack_sockaddr_in(port, ip))
      sock_tcp.send(encrypt(cmd), 0)
      byte_data = sock_tcp.recv(2048).bytes
      sock_tcp.close_write
      sock_tcp.close
      decrypt(byte_data.andand[4..])
    end
  rescue Errno::EINPROGRESS # Raised if the timeout period expires
    if sock_tcp.present?
      sock_tcp.close_write
      sock_tcp.close
      return send_tp_link(ip, cmd, retry_count + 1) if retry_count < 2
    end
    { "error" => "Connection timed out after three #{timeout_i} second retries" }.to_json
  rescue Timeout::Error, Errno::ETIMEDOUT # Raised if the timeout period expires
    if sock_tcp.present?
      sock_tcp.close_write
      sock_tcp.close
      return send_tp_link(ip, cmd, retry_count + 1) if retry_count < 2
    end
    { "error" => "Connection timed out after three #{timeout_i} second retries" }.to_json
  rescue StandardError => e
    { "error" => "#{e}\nCould not connect to host #{ip}:#{port}" }.to_json
  end

  private

  # These two class methods, encrypt and decrypt, perform a very simple form of
  # symmetric encryption and decryption on a given string.
  # They are symmetric in the sense that they use a shared
  # secret key to both encrypt and decrypt the data.
  # In this case, the secret key is a constant integer, 171.
  #
  def encrypt(string)
    return unless string.present?

    key = 171
    result = [string.length].pack("N")
    string.each_char do |i|
      a = key ^ i.ord
      key = a
      result << a.chr
    end
    result
  end

  def decrypt(string)
    key = 171
    result = []
    string.each do |i|
      a = key ^ i
      key = i
      result << a.chr
    end
    result.join
  end

  def perform(cmd)
    JSON.parse(send_tp_link(tpl_ip_address, COMMANDS[cmd]))
  end
end
