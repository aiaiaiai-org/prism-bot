# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Domain
    # Proof that a voice message was accepted as a native voice message. Exactly one of message_id
    # (a public message) or ephemeral_ref (a message only its receiver sees) is present, so a caller
    # cannot mistake one kind of delivery for the other.
    class VoiceReceipt
      attr_reader :message_id, :ephemeral_ref, :file_id

      def initialize(file_id:, message_id: nil, ephemeral_ref: nil)
        unless message_id.nil? ^ ephemeral_ref.nil?
          raise InputError.new("bot.voice.receipt.kind", "voice receipt must be either public or ephemeral")
        end
        unless message_id.nil? || (message_id.is_a?(Integer) && message_id.positive?)
          raise InputError.new("bot.voice.receipt.message.invalid", "voice message id is invalid")
        end
        unless ephemeral_ref.nil? || ephemeral_ref.is_a?(EphemeralMessageRef)
          raise InputError.new("bot.voice.receipt.ref.invalid", "voice ephemeral reference is invalid")
        end
        unless file_id.is_a?(String) && !file_id.empty?
          raise InputError.new("bot.voice.receipt.file.invalid", "voice file id is invalid")
        end

        @message_id = message_id
        @ephemeral_ref = ephemeral_ref
        @file_id = file_id.dup.freeze
        freeze
      end

      def ephemeral?
        !ephemeral_ref.nil?
      end
    end
  end
end
