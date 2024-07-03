module Entities
  class Sensor
    ATTRIBUTES_PUBLISH_WAIT = 60
    AVAILABILITY_PUBLISH_WAIT = 60
    DISCOVERY_PUBLISH_WAIT = 900
    STATE_PUBLISH_WAIT = 60

    attr_reader :device, :device_class,
                :unique_id, :name, :state,
                :thread_attribute, :thread_availability, :thread_state, 
                :topic_attribute, :topic_availability,
                :topic_discovery, :topic_state
    def initialize(device:, unique_id:, init_state:, name: nil)
      @device = device
      @device_class = :running
      @unique_id = unique_id
      @name = name || unique_id.sanitized_titlecase
      @state = init_state

      @topic_state = Config.prefixed_topic("#{unique_id}/state")
      @topic_attribute = Config.prefixed_topic("#{unique_id}/attribute")
      @topic_availability = Config.prefixed_topic("#{unique_id}/status")
      @topic_discovery = "#{Config::HOME_ASSISTANT_PREFIX}/#{component_type}/#{unique_id}/config"
    end

    def attributes
      {}
    end
    
    def publish_discovery!
      Config.singleton.mqtt_server.publish(topic, )
    end

    def setup_listeners!
    end

    def state=(new_value)
      if new_value != @state
        @state = new_value
        @thread_state.raise(Config::RestartError, 'State updated')
      end
    end

    def setup_publishers!
      @thread_discovery = Config.store_publisher_thread("#{unique_id}-discovery", DISCOVERY_PUBLISH_WAIT) do
        puts "Publishing discovery details for #{unique_id}"
        Config.singleton.mqtt_server.publish(topic_discovery, discovery_payload.to_json)
      end
      @thread_availability = Config.store_publisher_thread("#{unique_id}-availability", AVAILABILITY_PUBLISH_WAIT,
                                                           callback_on_offline: -> { Config.singleton.mqtt_server.publish(topic_availability, 'offline') }) do
        Thread.current["name"] = "#{unique_id}-availability"
        Config.singleton.mqtt_server.publish(topic_availability, 'online')
      end
      @thread_state = Config.store_publisher_thread("#{unique_id}-state", STATE_PUBLISH_WAIT) do
        puts "Publishing to state topic #{topic_state} for #{unique_id}"
        Config.singleton.mqtt_server.publish(topic_state, state)
      end
      @thread_attribute = Config.store_publisher_thread("#{unique_id}-attribute", ATTRIBUTES_PUBLISH_WAIT) do
        puts "Publishing to atrribute topic #{topic_attribute} for #{unique_id}"
        Config.singleton.mqtt_server.publish(topic_attribute, attributes)
      end
    end

    private

    def discovery_payload
      {
        availability: { topic: topic_availability },
        device: {
          connections: [['mac', device.mac_identifier]],
          hw_version: device.hw_version,
          identifiers: [device.identifier],
          name: device.name,
          manufacturer: device.manufacturer,
          model: device.model,
          sw_version: device.sw_version
        },
        json_attribute_topic: topic_attribute,
        name:,
        state_topic: topic_state,
        unique_id:
      }
    end

    def component_type
      'sensor'
    end
  end
end
