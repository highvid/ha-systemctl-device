module Entities
  class Button < Sensor
    attr_reader :topic_command

    def initialize(device:, unique_id:, init_state:, name: nil)
      super
      @topic_command = Config.prefixed_topic("#{unique_id}/command")
    end

    private
    
    def discovery_payload
      super.merge(command_topic: topic_command)
    end

    def component_type
      'button'
    end
  end
end
