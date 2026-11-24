# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      # A button press, as the bot needs it to route and answer it. The data is whatever the bot put
      # on the button and is untrusted: the person can only press, but a client may send anything.
      class CallbackContext
        MAX_DATA_BYTES = 64

        attr_reader :id, :data, :source_ephemeral_message_id

        # source_ephemeral_message_id is set when the pressed button sits on an ephemeral message,
        # which must then be edited with the ephemeral edit method; it is nil for a public message.
        def initialize(id:, data:, source_ephemeral_message_id: nil)
          unless id.is_a?(String) && !id.empty? && !id.match?(/[[:cntrl:]]/)
            raise InputError.new("bot.telegram.callback.id.invalid", "Telegram callback id is invalid")
          end
          unless data.is_a?(String) && (1..MAX_DATA_BYTES).cover?(data.bytesize) && data.valid_encoding?
            raise InputError.new("bot.telegram.callback.data.invalid", "Telegram callback data is invalid")
          end
          unless source_ephemeral_message_id.nil? ||
              (source_ephemeral_message_id.is_a?(Integer) && source_ephemeral_message_id.positive?)
            raise InputError.new("bot.telegram.callback.source.invalid", "Telegram callback source is invalid")
          end

          @id = id.dup.freeze
          @data = data.dup.freeze
          @source_ephemeral_message_id = source_ephemeral_message_id
          freeze
        end

        # "route:payload" splits at the first colon; data without one is all route.
        def route
          data.split(":", 2).first
        end

        def payload
          data.split(":", 2)[1].to_s
        end
      end
    end
  end
end
