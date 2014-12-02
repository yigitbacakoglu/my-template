module BaseHelper

  def format_date(date = nil)
    return "" if date.nil?
    date.strftime("%B %d at %I:%M%p")
  end

  #Adds line breaks to text
  def format_text(text)
    h(text.to_s).gsub(/\n/, '<br>').html_safe
  end


  ALERT_TYPES = [:error, :info, :success, :warning]

  def bootstrap_flash
    flash_messages = []
    flash.each do |type, message|
      # Skip empty messages, e.g. for devise messages set to nothing in a locale file.
      next if message.blank?

      type = :success if type == :notice
      type = :error   if type == :alert
      next unless ALERT_TYPES.include?(type)

      Array(message).each do |msg|
        text = content_tag(:div,
                           content_tag(:button, raw("&times;"), :class => "close", "data-dismiss" => "alert") +
                               msg.html_safe, :class => "alert fade in alert-#{type}")
        flash_messages << text if msg
      end
    end
    flash_messages.join("\n").html_safe
  end

  #fire_event("reservation_cancel")
  # Convenience method for firing instrumentation events with the default payload hash
  def fire_event(name, extra_payload = {})
    ActiveSupport::Notifications.instrument(name, default_notification_payload.merge(extra_payload))
  end


  # Creates the hash that is sent as the payload for all notifications. Specific notifications will
  # add additional keys as appropriate. Override this method if you need additional data when
  # responding to a notification
  def default_notification_payload
    {show: true, :user => (respond_to?(:current_user) && current_user)}
  end

end