# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      module Handlers
        class Channels
          def initialize(list_channels:, message_sender:, presenter:)
            @list_channels = list_channels
            @message_sender = message_sender
            @presenter = presenter
          end

          def call(update:, arguments:)
            values = @list_channels.call
            @message_sender.send_message(
              chat_id: update.chat_id,
              text: @presenter.channels(values)
            )
          end
        end
      end
    end
  end
end
