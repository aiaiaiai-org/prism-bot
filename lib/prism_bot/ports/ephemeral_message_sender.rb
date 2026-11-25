# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Ports
    # Messages only their receiver can see. Implementations must never fall back to a public
    # message: if private delivery is not confirmed, they raise MessageDeliveryError. Delivery is
    # not guaranteed even on success (the receiver may be offline), so a caller must not infer that
    # the person has seen the message.
    module EphemeralMessageSender
      # target is a Domain::EphemeralTarget, reply_markup a Domain::InlineKeyboard or nil.
      # Returns a Domain::EphemeralMessageRef.
      def send_ephemeral_message(target:, text:, reply_markup: nil)
        raise NotImplementedError
      end

      # ref is the Domain::EphemeralMessageRef returned when the message was sent. An edit that
      # passes no reply_markup is sent without buttons; resend them if they must stay.
      def edit_ephemeral_message(ref:, text:, reply_markup: nil)
        raise NotImplementedError
      end

      # Removes the message from the receiver's chat, for example a status that a result replaces.
      # Returns nil; raises MessageDeliveryError unless Telegram confirms. As with every private
      # message, the receiver may be offline and not see the removal.
      def delete_ephemeral_message(ref:)
        raise NotImplementedError
      end
    end
  end
end
