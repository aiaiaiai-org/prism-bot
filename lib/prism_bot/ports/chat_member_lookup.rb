# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Ports
    # Who is in a chat and with what standing. Telegram guarantees an answer about other people
    # only when this bot is an administrator of the chat; otherwise a lookup may fail, and a caller
    # must treat a failure as "not confirmed", never as an administrator.
    module ChatMemberLookup
      # Returns a Domain::ChatMembership, or raises MessageDeliveryError when Telegram does not
      # confirm the person in that chat.
      def chat_membership(chat_id:, user_id:)
        raise NotImplementedError
      end

      # This bot's own standing in the chat, for example to learn whether it is an administrator.
      def own_membership(chat_id:)
        raise NotImplementedError
      end
    end
  end
end
