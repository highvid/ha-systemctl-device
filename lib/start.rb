require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/object/blank'
require 'dbus/systemd'
require 'dotenv'
require 'mqtt'
require 'json'

require_relative './config'
require_relative './ext'
require_relative './entities'
require_relative './device'

Dotenv.load('.env.local') if File.exist?('.env.local')
require_relative './systemctl'

puts 'Config to be initialized!!'
Config.init!
puts 'Device to be initialized!!'
Device.new
Config.singleton.join!
