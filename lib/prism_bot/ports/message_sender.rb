# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Ports
    module MessageSender
      # location_request is the label of a one-tap button that asks the person to share their
      # position, or nil for none.
      def send_message(chat_id:, text:, message_thread_id: nil, location_request: nil)
        raise NotImplementedError
      end
    end
  end
end
