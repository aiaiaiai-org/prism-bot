# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      # Reads a webhook update as a group observation, or returns nil. It never raises: anything it
      # cannot read with certainty is not observed. Only text or caption from a human member of a
      # group or supergroup is kept. Private chats, channels, bots, anonymous or channel senders,
      # service messages, and every ephemeral message (see UpdateParser) are left out.
      class ObservationParser
        def call(value)
          return nil unless value.is_a?(Hash)

          edited = !value["message"].is_a?(Hash)
          message = edited ? value["edited_message"] : value["message"]
          return nil unless message.is_a?(Hash) && !private_message?(message)

          chat = message["chat"]
          return nil unless chat.is_a?(Hash) && %w[group supergroup].include?(chat["type"])

          sender = human_sender(message)
          text = textual_content(message)
          return nil unless sender && text

          Observation.new(
            update_id: value["update_id"],
            surface_context: SurfaceContext.new(
              chat_id: chat["id"], chat_type: chat["type"], message_thread_id: message["message_thread_id"],
              title: chat["title"]
            ),
            message_id: message["message_id"],
            author_id: sender["id"],
            username: sender["username"],
            display_name: [sender["first_name"], sender["last_name"]].grep(String).join(" "),
            text: text,
            sent_at: message["date"],
            edited: edited
          )
        rescue Error, KeyError, ArgumentError, TypeError
          nil
        end

        private

        # The markers UpdateParser reads as ephemeral; a message with any of them is private.
        def private_message?(message)
          message.key?("ephemeral_message_id") || message.key?("receiver_user") || message["message_id"] == 0
        end

        def human_sender(message)
          return nil if message.key?("sender_chat") || message.key?("via_bot")

          sender = message["from"]
          sender if sender.is_a?(Hash) && sender["is_bot"] != true
        end

        def textual_content(message)
          content = message["text"].is_a?(String) ? message["text"] : message["caption"]
          content if content.is_a?(String) && !content.empty?
        end
      end
    end
  end
end
