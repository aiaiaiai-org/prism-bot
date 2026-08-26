# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      module Handlers
        class Unknown
          def initialize(message_sender:, presenter:)
            @message_sender = message_sender
            @presenter = presenter
          end

          def call(update:, arguments:)
            @message_sender.send_message(chat_id: update.chat_id, text: @presenter.unknown)
          end
        end
      end
    end
  end
end
