# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      module Handlers
        class Lifecycle
          OPERATIONS = %i[status pause resume].freeze

          def initialize(operation:, lifecycle:, message_sender:, presenter:)
            @operation = operation.to_sym
            raise ArgumentError, "unsupported lifecycle operation" unless OPERATIONS.include?(@operation)

            @lifecycle = lifecycle
            @message_sender = message_sender
            @presenter = presenter
          end

          def call(update:, arguments:)
            state = @lifecycle.public_send(@operation, update)
            @message_sender.send_message(
              chat_id: update.chat_id,
              text: @presenter.lifecycle(@operation, state)
            )
          end
        end
      end
    end
  end
end
