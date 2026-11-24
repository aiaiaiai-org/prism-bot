# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Adapters
    module Telegram
      # The sender handed to handlers. A reply with no ephemeral target is public and goes through
      # the plain sender; a reply with one is private and goes through the ephemeral sender. A private
      # reply that cannot be delivered privately raises: there is no public fallback, so a handler
      # answering an ephemeral command or a button press cannot reveal that exchange to the group.
      class PrivateReplySender
        include Ports::MessageSender

        def initialize(public_sender:, ephemeral_sender:)
          @public_sender = public_sender
          @ephemeral_sender = ephemeral_sender
        end

        def send_message(chat_id:, text:, message_thread_id: nil, location_request: nil, ephemeral: nil)
          if ephemeral.nil?
            return @public_sender.send_message(
              chat_id: chat_id, text: text, message_thread_id: message_thread_id, location_request: location_request
            )
          end

          validate!(ephemeral, chat_id, message_thread_id, location_request)
          @ephemeral_sender.send_ephemeral_message(target: ephemeral, text: text)
          nil
        end

        private

        def validate!(ephemeral, chat_id, message_thread_id, location_request)
          unless ephemeral.is_a?(Domain::EphemeralTarget)
            raise InputError.new("bot.telegram.ephemeral.target.invalid", "ephemeral target is invalid")
          end
          # The reply keyboard that asks for a position cannot be shown privately, and a target for
          # another chat or topic must never be sent to this one.
          if location_request || ephemeral.chat_id != chat_id || ephemeral.message_thread_id != message_thread_id
            raise InputError.new("bot.telegram.ephemeral.target.mismatch", "ephemeral reply does not match its target")
          end
        end
      end
    end
  end
end
