# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class Update
        attr_reader :update_id, :chat_id, :user_id, :text, :surface_context

        def initialize(update_id:, chat_id:, user_id:, text:, surface_context: nil)
          @update_id = Integer(update_id)
          if @update_id.negative?
            raise InputError.new(
              "bot.telegram.update_id.invalid",
              "Telegram update id must not be negative"
            )
          end
          @chat_id = Integer(chat_id)
          @user_id = user_id.nil? ? nil : Integer(user_id)
          @text = String(text).dup.freeze
          @surface_context = surface_context || SurfaceContext.new(chat_id: @chat_id)
          unless @surface_context.is_a?(SurfaceContext) && @surface_context.chat_id == @chat_id
            raise InputError.new("bot.telegram.surface.mismatch", "Telegram surface does not match the update")
          end
          freeze
        end

        def reply_target
          surface_context.reply_target
        end
      end
    end
  end
end
