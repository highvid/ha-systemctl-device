class Device
  HW_VERSION = 'BlighVidMonitor1.0'.freeze
  MAC_IDENTIFIER = ENV.fetch('MAC_IDENTIFIER')
  MANUFACTURER = 'BlighVid Monitor'.freeze
  MODEL = 'Blighvid'.freeze
  NAME = 'Blighvid Process'.freeze
  IDENTIFIER = 'blighvid_processes'.freeze
  attr_accessor :attributes, :device_attributes, :entities

  def initialize
    @attributes = { ip: ENV.fetch('HOST_IP_ADDRESS') }
    @device_attributes = { manufacturer: MANUFACTURER, identifiers: [MAC_IDENTIFIER], hw_version: HW_VERSION }
    initialize_entities!
  end

  def name
    NAME
  end

  def identifier
    IDENTIFIER
  end

  def mac_identifier
    MAC_IDENTIFIER
  end

  def manufacturer
    MANUFACTURER
  end

  def model
    MODEL
  end

  def hw_version
    HW_VERSION
  end

  def sw_version
    Systemctl::VERSION
  end

  def restart!(service_name); end

  private

  def initialize_entity(name, status)
    if status.to_s == 'failed'
      Config.singleton.mqtt_server.publish("#{Config::HOME_ASSISTANT_PREFIX}/sensor/#{name}/config", '')
      Config.singleton.mqtt_server.publish("#{Config::HOME_ASSISTANT_PREFIX}/button/#{name}-button/config", '')
      return [nil, nil]
    end
    [name, {
      sensor: Entities::Sensor.new(device: self, unique_id: name, init_state: status),
      button: Entities::Button.new(device: self, unique_id: "#{name}-button", init_state: 'off',
                                   name: "#{name.sanitized_titlecase} Restart")
    }]
  end

  def initialize_entities!
    @entities = all_processes.to_h { |entity_name, status| initialize_entity(entity_name, status) }.compact
    setup_listeners_and_publishers!
  end

  def all_processes
    @all_processes = Dir.glob('*', base: ENV.fetch('BASE_PATH')).select do |f|
      File.symlink?(File.join(ENV.fetch('BASE_PATH'), f))
    end
    @all_processes = @all_processes.to_h do |dir|
      if filtered_out?(dir)
        [nil, nil]
      else
        [dir, DBus::Systemd::Unit.new("docker-compose@#{dir}.service").properties['ActiveState']]
      end
    rescue DBus::Error
      [dir, 'failed']
    end.compact
    @all_processes
  end

  def filtered_out?(dir)
    %w[systemctl-device staging-homeassistant].include?(dir.to_s)
  end

  def setup_listeners_and_publishers!
    setup_publishers!
    setup_entity_updaters!
    setup_listeners!
  end

  def setup_listeners!
    @entities.each_value { |entity_group| Config.singleton.mqtt_server.subscribe(entity_group[:button].topic_command) }
    Config.store_publisher_thread('device-listener', 0) do
      Config.singleton.mqtt_server.get do |topic, message|
        if message == 'PRESS'
          service_name = topic.gsub(%r{^blighvid/systemctl/}, '').gsub(%r{-button/command$}, '')
          service = DBus::Systemd::Unit.new("docker-compose@#{service_name}.service")
          service.Restart('replace')
        end
      end
    end
  end

  def setup_publishers!
    @entities.each_value do |entity_group|
      entity_group[:sensor].setup_publishers!
      entity_group[:button].setup_publishers!
    end
  end

  def setup_entity_updaters!
    Config.store_publisher_thread('device-updater', 3) do
      all_processes.each do |entity_name, status|
        @entities[entity_name] ||= initialize_entity(entity_name, status)
        @entities[entity_name][:sensor].send(:state=, status)
      end
    end
  end
end
