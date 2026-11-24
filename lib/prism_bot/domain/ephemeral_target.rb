# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Domain
    # Where one ephemeral message goes: a message only its receiver (and the bot) can see, in a
    # group or topic. The target also records which authority entitles the bot to send it, because
    # the platform gives a bot that right only in these cases:
    #
    # - reply_to_callback: the receiver just pressed a button; answer within 15 seconds.
    # - reply_to_ephemeral: the receiver just sent an ephemeral command or message; reply within
    #   15 seconds.
    # - to_member: no recent action by the receiver; only a chat administrator bot may do this.
    #
    # The receiver is always known. Even when the platform does not need it, the sender checks the
    # response against it, so a message that reached someone else is reported as a failure.
    class EphemeralTarget
      MODES = %i[callback reply member].freeze

      attr_reader :mode, :chat_id, :message_thread_id, :receiver_user_id, :callback_query_id,
        :reply_ephemeral_message_id

      def self.reply_to_callback(chat_id:, receiver_user_id:, callback_query_id:, message_thread_id: nil)
        new(
          mode: :callback,
          chat_id: chat_id,
          message_thread_id: message_thread_id,
          receiver_user_id: receiver_user_id,
          callback_query_id: callback_query_id
        )
      end

      def self.reply_to_ephemeral(chat_id:, receiver_user_id:, ephemeral_message_id:, message_thread_id: nil)
        new(
          mode: :reply,
          chat_id: chat_id,
          message_thread_id: message_thread_id,
          receiver_user_id: receiver_user_id,
          reply_ephemeral_message_id: ephemeral_message_id
        )
      end

      def self.to_member(chat_id:, receiver_user_id:, message_thread_id: nil)
        new(
          mode: :member,
          chat_id: chat_id,
          message_thread_id: message_thread_id,
          receiver_user_id: receiver_user_id
        )
      end

      def initialize(mode:, chat_id:, receiver_user_id:, message_thread_id: nil, callback_query_id: nil,
        reply_ephemeral_message_id: nil)
        unless MODES.include?(mode)
          raise InputError.new("bot.ephemeral.target.mode.invalid", "ephemeral target mode is invalid")
        end
        unless chat_id.is_a?(Integer) && !chat_id.zero?
          raise InputError.new("bot.ephemeral.target.chat.invalid", "ephemeral target chat is invalid")
        end
        unless message_thread_id.nil? || (message_thread_id.is_a?(Integer) && message_thread_id.positive?)
          raise InputError.new("bot.ephemeral.target.thread.invalid", "ephemeral target topic is invalid")
        end
        unless receiver_user_id.is_a?(Integer) && receiver_user_id.positive?
          raise InputError.new("bot.ephemeral.target.receiver.invalid", "ephemeral receiver is invalid")
        end
        validate_authority!(mode, callback_query_id, reply_ephemeral_message_id)

        @mode = mode
        @chat_id = chat_id
        @message_thread_id = message_thread_id
        @receiver_user_id = receiver_user_id
        @callback_query_id = callback_query_id&.dup&.freeze
        @reply_ephemeral_message_id = reply_ephemeral_message_id
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
        [mode, chat_id, message_thread_id, receiver_user_id, callback_query_id, reply_ephemeral_message_id]
      end

      private

      def validate_authority!(mode, callback_query_id, reply_ephemeral_message_id)
        callback_valid = callback_query_id.is_a?(String) && !callback_query_id.empty? &&
          !callback_query_id.match?(/[[:cntrl:]]/)
        reply_valid = reply_ephemeral_message_id.is_a?(Integer) && reply_ephemeral_message_id.positive?

        valid = case mode
        when :callback then callback_valid && reply_ephemeral_message_id.nil?
        when :reply then reply_valid && callback_query_id.nil?
        else callback_query_id.nil? && reply_ephemeral_message_id.nil?
        end
        return if valid

        raise InputError.new(
          "bot.ephemeral.target.authority.invalid",
          "ephemeral target authority does not match its mode"
        )
      end
    end
  end
end
