#!/usr/bin/env ruby
# frozen_string_literal: true

#
# This is a translation of the original python script to ruby
# TP-Link Wi-Fi Smart Plug Protocol Client
# For use with TP-Link HS-100 or HS-110
#
# by Lubomir Stroetmann
# Copyright 2016 softScheck GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'Socket'
require 'optparse'

version = 0.4

# Check if hostname is valid
def validHostname(hostname)
  begin
    Socket.gethostbyname(hostname)
  rescue Exception => e
    # TODO parser.error("Invalid hostname.")
  end
  return hostname
end

# Check if port is valid
def validPort(port)
  begin
    port = int(port)
  rescue Exception => e
    # TODO parser.error("Invalid port number.")
  end
  if ((port <= 1024) or (port > 65535))
    # TODO parser.error("Invalid port number.")
  end
  return port
end

# Predefined Smart Plug Commands
# For a full list of commands, consult tplink_commands.txt
commands = { 'info' => "{'system':{'get_sysinfo':{}}}",
             'on' => '{"system":{"set_relay_state":{"state":1}}}',
             'off' => '{"system":{"set_relay_state":{"state":0}}}',
             'ledoff' => '{"system":{"set_led_off":{"off":1}}}',
             'ledon' => '{"system":{"set_led_off":{"off":0}}}',
             'cloudinfo' => '{"cnCloud":{"get_info":{}}}',
             'wlanscan' => '{"netif":{"get_scaninfo":{"refresh":0}}}',
             'time' => '{"time":{"get_time":{}}}',
             'schedule' => '{"schedule":{"get_rules":{}}}',
             'countdown' => '{"count_down":{"get_rules":{}}}',
             'antitheft' => '{"anti_theft":{"get_rules":{}}}',
             'reboot' => '{"system":{"reboot":{"delay":1}}}',
             'reset' => '{"system":{"reset":{"delay":1}}}',
             'energy' => '{"emeter":{"get_realtime":{}}}'
}

# Encryption and Decryption of TP-Link Smart Home Protocol
# XOR Autokey Cipher with starting key = 171

def encrypt(string)
  key = 171
  result = [string.length].pack("N")
  string.each_char do |i|
    a = key ^ i.ord
    key = a
    result << a.chr
  end
  return result
end

def decrypt(string)
  key = 171
  result = [string.length].pack("N")
  string.each do |i|
    a = key ^ i.ord
    key = i.ord
    result << a.chr
  end
  return result[4..-1]
end

# Parse commandline arguments
options = { port: 9999, timeout: 10 }
OptionParser.new do |opts|
  opts.banner = "TP-Link Wi-Fi Smart Plug Client v#{version}\nUsage: tplink.rb [options]"
  opts.on("-t", "--target <hostname> (required)", "Target hostname or IP address")
  opts.on("-p", "--port <port>", Integer, 'Port (default: 9999)')
  opts.on("-q", "--quiet", "Only show result")
  opts.on("--timeout <timeout>", Integer, "Timeout to establish connection")
  opts.on("-c", "--command <command>", commands.keys, "Preset command to send. Choices are: #{commands.keys.join(", ")}") do |command|
    raise (OptionParser::InvalidOption.new("Mutually exclusive options: --command & --json can't be provided together.")) if options[:json]
    options[:command] = command
  end
  opts.on("-j", "--json <JSON string>", "Full JSON string of command to send") do |json|
    raise OptionParser::InvalidOption.new("Mutually exclusive options: --command & --json can't be provided together.") if options[:command]
    options[:json] = json
  end
end.parse!(into: options)

if options[:command].to_s.strip.empty?
  cmd = options[:json]
else
  cmd = commands[options[:command]]
end

# Send command and receive reply
begin
  ip = options[:target]
  port = options[:port].to_i
  timeout = options[:timeout].to_i
  sock_tcp = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
  sock_tcp.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, [timeout, 0].pack('l_2'))
  sock_tcp.connect(Socket.pack_sockaddr_in(port, ip))
  sock_tcp.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, [0, 0].pack('l_2'))
  sock_tcp.send(encrypt(cmd),0)
  byte_data = sock_tcp.recv(2048).bytes
  sock_tcp.close_write()
  sock_tcp.close

  decrypted = decrypt(byte_data[4..-1])

  if options[:quiet]
    puts(decrypted)
  else
    puts("Sent:     #{cmd}")
    puts("Received: #{decrypted}")
  end
rescue Errno::EINPROGRESS # Raised if the timeout period expires
  sock_tcp.close_write()
  sock_tcp.close
  puts "Connection timed out after #{timeout} seconds"
rescue Errno::ETIMEDOUT # Ra
  sock_tcp.close_write()
  sock_tcp.close
  puts "Connection timed out after #{timeout} seconds"
rescue Exception => e
  puts "#{e}"
  puts "Could not connect to host #{ip}:#{port}"
end
