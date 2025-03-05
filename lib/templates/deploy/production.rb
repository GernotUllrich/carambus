# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

# server '172.24.1.53', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"} # phat
# server '192.168.178.79', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"}
# server '192.168.178.57', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"}
# server '192.168.2.231', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"}
# server '192.168.178.66', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"} # pi4b
# server '192.168.178.89', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"} # pi4
# server '192.168.178.60', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"} # pi4bcw
# server '192.168.178.53', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"} # pi4bcww
# server '192.168.178.81', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"} # pi4bw
# server '192.168.178.91', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"} # pi4w
# server '192.168.178.60', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"} # pi4bcw
# server '192.168.2.210', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"} # bcw
# server '192.168.178.107', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"} # bvbw
server 'api.carambus.de', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"}

# server "bc-wedel.duckdns.org", user: "www-data", roles: %w[app db web], ssh_options: {port: "8910"} # bc-wedel
# server 'carambus.de', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"} # carambus global
# server '192.168.178.81', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"} # carambus global
# server 'db.carambus.de', user: 'deploy', roles: %w{db}

# set :rbenv_path, '/var/www/.rbenv'
# set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"

# role-based syntax
# ==================

# Defines a role with one or multiple servers. The primary server in each
# group is considered to be the first unless any  hosts have the primary
# property set. Specify the username and a domain or IP for the server.
# Don't use `:all`, it's a meta role.

# role :app, %w{deploy@carambus.de}, my_property: :my_value
# role :web, %w{user1@primary.com user2@additional.com}, other_property: :other_value
# role :db,  %w{deploy@carambus.de}

# Configuration
# =============
# You can set any configuration variable like in config/deploy.rb
# These variables are then only loaded and set in this stage.
# For available Capistrano configuration variables see the documentation page.
# http://capistranorb.com/documentation/getting-started/configuration/
# Feel free to add new variables to customise your setup.

# Custom SSH Options
# ==================
# You may pass any option but keep in mind that net/ssh understands a
# limited set of options, consult the Net::SSH documentation.
# http://net-ssh.github.io/net-ssh/classes/Net/SSH.html#method-c-start
#
# Global options
# --------------
#  set :ssh_options, {
#    keys: %w(/home/rlisowski/.ssh/id_rsa),
#    forward_agent: false,
#    auth_methods: %w(password)
#  }
#
# The server-based syntax can be used to override options:
# ------------------------------------
# server 'carambus.de',
#   user: 'user_name',
#   roles: %w{web app},
#   ssh_options: {
#     user: 'user_name', # overrides user setting above
#     keys: %w(/home/user_name/.ssh/id_rsa),
#     forward_agent: false,
#     auth_methods: %w(publickey password)
#     # password: 'please use keys'
#   }
