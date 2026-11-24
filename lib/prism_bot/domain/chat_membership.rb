# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Domain
    # A person's (or this bot's) standing in one chat, as Telegram reports it.
    class ChatMembership
      STATUSES = %w[creator administrator member restricted left kicked].freeze

      attr_reader :chat_id, :user_id, :status

      def initialize(chat_id:, user_id:, status:)
        unless chat_id.is_a?(Integer) && !chat_id.zero?
          raise InputError.new("bot.membership.chat.invalid", "membership chat is invalid")
        end
        unless user_id.is_a?(Integer) && user_id.positive?
          raise InputError.new("bot.membership.user.invalid", "membership user is invalid")
        end
        unless STATUSES.include?(status)
          raise InputError.new("bot.membership.status.invalid", "membership status is invalid")
        end

        @chat_id = chat_id
        @user_id = user_id
        @status = status.dup.freeze
        freeze
      end

      # The creator or an administrator: the only people allowed to switch a chat feature on.
      def administrator?
        %w[creator administrator].include?(status)
      end

      # Still in the chat. A restricted member may have been muted but is present.
      def present?
        !%w[left kicked].include?(status)
      end
    end
  end
end
