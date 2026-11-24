# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Domain
    # Buttons under a message. Every button carries callback data, so a press comes back to the bot
    # as a callback; there are no link buttons, which keeps a private message from opening anything.
    class InlineKeyboard
      MAX_ROWS = 20
      MAX_BUTTONS_PER_ROW = 8
      MAX_BUTTONS = 100
      MAX_LABEL_CHARACTERS = 64
      MAX_CALLBACK_DATA_BYTES = 64

      class Button
        attr_reader :text, :callback_data

        def initialize(text:, callback_data:)
          unless text.is_a?(String) && (1..MAX_LABEL_CHARACTERS).cover?(text.length) && !text.match?(/[[:cntrl:]]/)
            raise InputError.new("bot.keyboard.button.text.invalid", "keyboard button label is invalid")
          end
          unless callback_data.is_a?(String) && (1..MAX_CALLBACK_DATA_BYTES).cover?(callback_data.bytesize) &&
              callback_data.valid_encoding?
            raise InputError.new("bot.keyboard.button.data.invalid", "keyboard button callback data is invalid")
          end

          @text = text.dup.freeze
          @callback_data = callback_data.dup.freeze
          freeze
        end
      end

      attr_reader :rows

      # rows is an array of rows, each an array of {text:, callback_data:} pairs or Buttons.
      def initialize(rows:)
        unless rows.is_a?(Array) && (1..MAX_ROWS).cover?(rows.length)
          raise InputError.new("bot.keyboard.rows.invalid", "keyboard rows are invalid")
        end

        built = rows.map do |row|
          unless row.is_a?(Array) && (1..MAX_BUTTONS_PER_ROW).cover?(row.length)
            raise InputError.new("bot.keyboard.row.invalid", "keyboard row is invalid")
          end

          row.map { |button| button.is_a?(Button) ? button : Button.new(**button) }.freeze
        end
        if built.sum(&:length) > MAX_BUTTONS
          raise InputError.new("bot.keyboard.buttons.invalid", "keyboard has too many buttons")
        end

        @rows = built.freeze
        freeze
      end
    end
  end
end
