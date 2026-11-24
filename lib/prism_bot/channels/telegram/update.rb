# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class Update
        attr_reader :update_id, :chat_id, :user_id, :text, :surface_context, :location, :callback,
          :ephemeral_message_id

        # ephemeral_message_id marks a message the person sent privately (an ephemeral command);
        # callback marks a button press. Either makes the update private: replies go back to that
        # person only (see #reply_target), and its text is not group content.
        def initialize(update_id:, chat_id:, user_id:, text:, surface_context: nil, location: nil,
          callback: nil, ephemeral_message_id: nil)
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
          unless location.nil? || location.is_a?(Domain::Location)
            raise InputError.new("bot.telegram.location.invalid", "Telegram location is invalid")
          end
          @location = location
          unless callback.nil? || callback.is_a?(CallbackContext)
            raise InputError.new("bot.telegram.callback.invalid", "Telegram callback is invalid")
          end
          unless ephemeral_message_id.nil? || (ephemeral_message_id.is_a?(Integer) && ephemeral_message_id.positive?)
            raise InputError.new("bot.telegram.ephemeral.invalid", "Telegram ephemeral message is invalid")
          end
          if (callback || ephemeral_message_id) && @user_id.nil?
            raise InputError.new("bot.telegram.ephemeral.sender.invalid", "a private update needs a human sender")
          end
          @callback = callback
          @ephemeral_message_id = ephemeral_message_id
          freeze
        end

        # Sent only to its sender, never to the group.
        def private?
          !callback.nil? || !ephemeral_message_id.nil?
        end

        # Where to answer. Public updates answer in the chat or topic. A private update also carries
        # the ephemeral target, so a sender that honours it can only reach the person who acted.
        def reply_target
          target = surface_context.reply_target
          return target unless private?

          target.merge(ephemeral: ephemeral_target).freeze
        end

        # The ephemeral message that carries the pressed button, for editing it in place, or nil.
        def source_ephemeral_ref
          source = callback&.source_ephemeral_message_id
          return nil unless source

          Domain::EphemeralMessageRef.new(chat_id: chat_id, receiver_user_id: user_id, ephemeral_message_id: source)
        end

        private

        def ephemeral_target
          thread = surface_context.message_thread_id
          if callback
            Domain::EphemeralTarget.reply_to_callback(
              chat_id: chat_id, receiver_user_id: user_id, callback_query_id: callback.id, message_thread_id: thread
            )
          else
            Domain::EphemeralTarget.reply_to_ephemeral(
              chat_id: chat_id, receiver_user_id: user_id, ephemeral_message_id: ephemeral_message_id,
              message_thread_id: thread
            )
          end
        end
      end
    end
  end
end
