class String
  def sanitized_titlecase
    downcase
      .gsub('homeassistant', 'home assistant')
      .titlecase
      .gsub(/([ -_]|^)Ha([\b_ ]|$)/, '\1HA\2')
      .gsub(/([ -_]|^)Mqtt([\b_ ]|$)/, '\1MQTT\2')
  end
end
