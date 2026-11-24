# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Ports
    # Telegram shows a progress bar on a pressed button until the bot answers its callback query,
    # even when the real reply is a separate message.
    module CallbackAnswerer
      # text, when given, is a short notice shown to the person who pressed (at most 200 characters).
      def answer_callback_query(callback_query_id:, text: nil)
        raise NotImplementedError
      end
    end
  end
end
