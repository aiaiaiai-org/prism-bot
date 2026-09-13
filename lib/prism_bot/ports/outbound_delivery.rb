# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Ports
    module OutboundDelivery
      def deliver_message(chat_id:, text:, idempotency_key:, message_thread_id: nil)
        raise NotImplementedError
      end
    end
  end
end
