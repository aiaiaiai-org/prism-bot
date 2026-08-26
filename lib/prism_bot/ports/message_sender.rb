# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Ports
    module MessageSender
      def send_message(chat_id:, text:)
        raise NotImplementedError
      end
    end
  end
end
