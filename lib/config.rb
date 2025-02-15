class Config
  HOME_ASSISTANT_PREFIX = 'homeassistant'.freeze
  class RestartError < StandardError; end
  class OfflineError < StandardError; end
  attr_accessor :publisher_threads, :mqtt_server

  def initialize
    Thread.report_on_exception = false
    @publisher_threads = []
    @mqtt_server = MQTT::Client.connect(host: ENV.fetch('MQTT_HOST'),
                                        port: ENV.fetch('MQTT_PORT', '1883'),
                                        username: ENV.fetch('MQTT_USERNAME'),
                                        password: ENV.fetch('MQTT_PASSWORD'))
    puts 'Configuration initialized!!'
  end

  class << self
    def init!
      singleton
    end

    def singleton
      @singleton ||= Config.new
    end

    def prefixed_topic(name)
      "blighvid/systemctl/#{name}"
    end

    def store_publisher_thread(name, delay_in_seconds, callback_on_offline: nil)
      thread = inifinite_threadize(name, delay_in_seconds, callback_on_offline:) { yield if block_given? }
      singleton.publisher_threads << thread
      thread
    end

    def inifinite_threadize(name, delay_in_seconds, callback_on_offline:)
      threadize(name) do
        loop do
          yield if block_given?
          sleep delay_in_seconds
        end
      rescue RestartError
        retry
      rescue OfflineError
        callback_on_offline.call if callback_on_offline.present?
      end
    end

    def threadize(name)
      Thread.new do
        Thread.current['name'] = name
        yield if block_given?
      rescue StandardError => e
        puts "Error: #{e.message}"
        puts e.backtrace.join("\n")
      end
    end
  end

  def join!
    publisher_threads.each(&:join)
  rescue SignalException
    publisher_threads.each { |thread| thread.raise(Config::OfflineError, 'Offline') }
    publisher_threads.each(&:join)
  end
end
