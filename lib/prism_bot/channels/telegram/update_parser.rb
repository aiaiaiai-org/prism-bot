# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class UpdateParser
        def call(value)
          unless value.is_a?(Hash)
            raise InputError.new("bot.telegram.update.invalid", "Telegram update must be a JSON object")
          end

          message = value["message"] || value["channel_post"]
          # A live position is kept up to date by Telegram as edits of the message that shared it.
          message ||= value["edited_message"] if live_location?(value["edited_message"])
          return nil unless message.is_a?(Hash)

          location = location_of(message)
          return nil unless message["text"].is_a?(String) || location

          chat = message.fetch("chat")
          unless chat.is_a?(Hash) && %w[private group supergroup channel].include?(chat["type"])
            raise InputError.new("bot.telegram.surface.invalid", "Telegram chat type is invalid")
          end
          surface = SurfaceContext.new(
            chat_id: chat.fetch("id"),
            chat_type: chat.fetch("type"),
            message_thread_id: message["message_thread_id"],
            title: chat["title"]
          )

          Update.new(
            update_id: value.fetch("update_id"),
            chat_id: surface.chat_id,
            user_id: human_user_id(message, surface),
            text: message["text"].to_s,
            surface_context: surface,
            location: location
          )
        rescue KeyError, ArgumentError, TypeError
          raise InputError.new(
            "bot.telegram.update.invalid",
            "Telegram text update is missing required identifiers"
          )
        end

        private

        def live_location?(message)
          message.is_a?(Hash) && message["location"].is_a?(Hash) && message["location"].key?("live_period")
        end

        def location_of(message)
          position = message["location"]
          return nil unless position.is_a?(Hash)

          Domain::Location.new(
            latitude: position.fetch("latitude"),
            longitude: position.fetch("longitude"),
            live: position.key?("live_period")
          )
        end

        def human_user_id(message, surface)
          return nil if surface.chat_type == "channel" || message.key?("sender_chat")

          sender = message["from"]
          return nil unless sender.is_a?(Hash) && sender["is_bot"] != true

          identifier = sender["id"]
          return identifier if identifier.is_a?(Integer) && identifier.positive?

          raise InputError.new("bot.telegram.sender.invalid", "Telegram sender is invalid")
        end
      end
    end
  end
end
