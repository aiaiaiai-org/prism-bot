# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class SurfaceContext
        CHAT_TYPES = %w[private group supergroup channel unknown].freeze

        attr_reader :chat_id, :chat_type, :message_thread_id, :title

        def initialize(chat_id:, chat_type: "unknown", message_thread_id: nil, title: nil)
          unless chat_id.is_a?(Integer) && !chat_id.zero? && CHAT_TYPES.include?(chat_type)
            raise InputError.new("bot.telegram.surface.invalid", "Telegram surface is invalid")
          end
          # Bot API topics also exist in private chats of bots with forum topic mode enabled.
          # https://core.telegram.org/bots/api#sendmessage
          if !message_thread_id.nil? &&
              (!message_thread_id.is_a?(Integer) || !message_thread_id.positive? ||
              !%w[private supergroup].include?(chat_type))
            raise InputError.new("bot.telegram.surface.thread.invalid", "Telegram topic is invalid")
          end
          unless title.nil? || title.is_a?(String)
            raise InputError.new("bot.telegram.surface.title.invalid", "Telegram chat title is invalid")
          end

          @chat_id = chat_id
          @chat_type = chat_type.dup.freeze
          @message_thread_id = message_thread_id
          @title = title&.dup&.freeze
          freeze
        end

        def kind
          message_thread_id ? "forum_topic" : chat_type
        end

        def interaction_scope
          "telegram:#{chat_id}:#{message_thread_id || 'root'}"
        end

        def reply_target
          target = {chat_id: chat_id}
          target[:message_thread_id] = message_thread_id if message_thread_id
          target.freeze
        end
      end
    end
  end
end
