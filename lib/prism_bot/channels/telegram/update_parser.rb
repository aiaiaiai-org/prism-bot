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
          return nil unless message.is_a?(Hash) && message["text"].is_a?(String)

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
            text: message.fetch("text"),
            surface_context: surface
          )
        rescue KeyError, ArgumentError, TypeError
          raise InputError.new(
            "bot.telegram.update.invalid",
            "Telegram text update is missing required identifiers"
          )
        end

        private

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
