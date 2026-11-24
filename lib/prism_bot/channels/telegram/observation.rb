# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      # One ordinary group message (or edit of one) as an observer sees it: the content of a
      # chat, not a request to the bot. It is immutable, carries no private updates (ephemeral
      # commands and button presses are never observed), and says nothing about who may read it:
      # a product must keep only what a chat has explicitly opted in to.
      class Observation
        attr_reader :update_id, :surface_context, :message_id, :author_id, :username, :display_name,
          :text, :sent_at

        # sent_at is the original message date in seconds, never the time of an edit. The update id
        # is strictly increasing across updates, so it orders an edit after the message it edits.
        def initialize(update_id:, surface_context:, message_id:, author_id:, text:, sent_at:, display_name:,
          username: nil, edited: false)
          valid = update_id.is_a?(Integer) && !update_id.negative? &&
            surface_context.is_a?(SurfaceContext) && %w[group supergroup].include?(surface_context.chat_type) &&
            message_id.is_a?(Integer) && message_id.positive? &&
            author_id.is_a?(Integer) && author_id.positive? &&
            text.is_a?(String) && !text.empty? &&
            sent_at.is_a?(Integer) && sent_at.positive? &&
            display_name.is_a?(String) && (username.nil? || username.is_a?(String)) &&
            (edited == true || edited == false)
          raise InputError.new("bot.telegram.observation.invalid", "Telegram observation is invalid") unless valid

          @update_id = update_id
          @surface_context = surface_context
          @message_id = message_id
          @author_id = author_id
          @text = text.dup.freeze
          @sent_at = sent_at
          @display_name = display_name.dup.freeze
          @username = username&.dup&.freeze
          @edited = edited
          freeze
        end

        def chat_id
          surface_context.chat_id
        end

        def message_thread_id
          surface_context.message_thread_id
        end

        def edited?
          @edited
        end

        # A slash command is a request to the bot, not conversation, so most observers skip it.
        def command?
          !Command.parse(text).nil?
        end
      end
    end
  end
end
