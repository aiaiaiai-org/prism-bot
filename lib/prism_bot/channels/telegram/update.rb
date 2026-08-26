# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class Update
        attr_reader :update_id, :chat_id, :user_id, :text

        def initialize(update_id:, chat_id:, user_id:, text:)
          @update_id = Integer(update_id)
          if @update_id.negative?
            raise InputError.new(
              "bot.telegram.update_id.invalid",
              "Telegram update id must not be negative"
            )
          end
          @chat_id = Integer(chat_id)
          @user_id = Integer(user_id)
          @text = String(text).dup.freeze
          freeze
        end
      end
    end
  end
end
