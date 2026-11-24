# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Domain
    # A sent ephemeral message, as needed to edit it later. Ephemeral message identifiers are
    # scoped to the chat and may be reused after the message is deleted or expires, so a reference
    # is only meaningful together with its chat and receiver.
    class EphemeralMessageRef
      attr_reader :chat_id, :receiver_user_id, :ephemeral_message_id

      def initialize(chat_id:, receiver_user_id:, ephemeral_message_id:)
        unless chat_id.is_a?(Integer) && !chat_id.zero?
          raise InputError.new("bot.ephemeral.ref.chat.invalid", "ephemeral message chat is invalid")
        end
        unless receiver_user_id.is_a?(Integer) && receiver_user_id.positive?
          raise InputError.new("bot.ephemeral.ref.receiver.invalid", "ephemeral message receiver is invalid")
        end
        unless ephemeral_message_id.is_a?(Integer) && ephemeral_message_id.positive?
          raise InputError.new("bot.ephemeral.ref.id.invalid", "ephemeral message id is invalid")
        end

        @chat_id = chat_id
        @receiver_user_id = receiver_user_id
        @ephemeral_message_id = ephemeral_message_id
        freeze
      end

      def ==(other)
        other.is_a?(self.class) && state == other.state
      end
      alias_method :eql?, :==

      def hash
        state.hash
      end

      protected

      def state
        [chat_id, receiver_user_id, ephemeral_message_id]
      end
    end
  end
end
