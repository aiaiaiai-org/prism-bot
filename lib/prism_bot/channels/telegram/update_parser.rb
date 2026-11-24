# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class UpdateParser
        def call(value)
          unless value.is_a?(Hash)
            raise InputError.new("bot.telegram.update.invalid", "Telegram update must be a JSON object")
          end

          return parse_callback(value) if value["callback_query"].is_a?(Hash)

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
            location: location,
            ephemeral_message_id: ephemeral_message_id_of(message)
          )
        rescue KeyError, ArgumentError, TypeError
          raise InputError.new(
            "bot.telegram.update.invalid",
            "Telegram text update is missing required identifiers"
          )
        end

        private

        # A button press. Anything the bot cannot answer privately and safely is ignored rather
        # than guessed at: a press on an inline-mode or inaccessible message, in a channel, by a
        # bot, or without data (a game).
        def parse_callback(value)
          query = value["callback_query"]
          message = query["message"]
          sender = query["from"]
          return nil unless message.is_a?(Hash) && sender.is_a?(Hash) && query["data"].is_a?(String)
          return nil if sender["is_bot"] == true || message["date"] == 0

          chat = message.fetch("chat")
          return nil unless chat.is_a?(Hash) && %w[private group supergroup].include?(chat["type"])

          surface = SurfaceContext.new(
            chat_id: chat.fetch("id"),
            chat_type: chat.fetch("type"),
            message_thread_id: message["message_thread_id"],
            title: chat["title"]
          )
          Update.new(
            update_id: value.fetch("update_id"),
            chat_id: surface.chat_id,
            user_id: sender.fetch("id"),
            text: "",
            surface_context: surface,
            callback: CallbackContext.new(
              id: query["id"],
              data: query["data"],
              source_ephemeral_message_id: ephemeral_message_id_of(message)
            )
          )
        rescue KeyError, ArgumentError, TypeError
          raise InputError.new("bot.telegram.update.invalid", "Telegram callback is missing required identifiers")
        end

        # Telegram marks an ephemeral message with ephemeral_message_id and receiver_user, and gives
        # it message_id 0. Any marker makes the message private, so a marker without a usable id is
        # an error, never a public message.
        def ephemeral_message_id_of(message)
          marked = message.key?("ephemeral_message_id") || message.key?("receiver_user") || message["message_id"] == 0
          return nil unless marked

          identifier = message["ephemeral_message_id"]
          return identifier if identifier.is_a?(Integer) && identifier.positive?

          raise InputError.new("bot.telegram.ephemeral.invalid", "Telegram ephemeral message is invalid")
        end

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
