# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Ports
    module MessageSender
      # location_request is the label of a one-tap button that asks the person to share their
      # position, or nil for none.
      # ephemeral is a Domain::EphemeralTarget for a reply that only one person may see; it is set in
      # the reply target of a private update. A sender given one must deliver privately or raise,
      # never as a public message, and cannot combine it with location_request.
      def send_message(chat_id:, text:, message_thread_id: nil, location_request: nil, ephemeral: nil)
        raise NotImplementedError
      end
    end
  end
end
