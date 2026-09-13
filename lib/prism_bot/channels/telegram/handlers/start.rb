# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      module Handlers
        class Start
          def initialize(message_sender:, presenter:)
            @message_sender = message_sender
            @presenter = presenter
          end

          def call(update:, arguments:)
            @message_sender.send_message(
              **update.reply_target,
              text: [@presenter.context_card(update.surface_context), @presenter.started(update.actor)].join("\n\n")
            )
          end
        end
      end
    end
  end
end
