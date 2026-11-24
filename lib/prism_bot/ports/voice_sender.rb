# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Ports
    # Native voice messages. The private and the public send are separate methods on purpose: a
    # missing target must never turn a private voice into a public one.
    module VoiceSender
      # A voice only target.receiver_user_id can see. Returns a Domain::VoiceReceipt with an
      # ephemeral reference. Raises MessageDeliveryError unless Telegram confirms an ephemeral
      # native voice message for that receiver.
      def send_ephemeral_voice(target:, clip:, caption:)
        raise NotImplementedError
      end

      # A voice visible to everyone in the chat or topic. Only for an explicit, user-confirmed
      # share. Returns a Domain::VoiceReceipt with a message id.
      def send_public_voice(chat_id:, clip:, caption:, message_thread_id: nil)
        raise NotImplementedError
      end
    end
  end
end
