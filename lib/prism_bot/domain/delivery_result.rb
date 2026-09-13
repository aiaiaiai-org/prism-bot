# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Domain
    class DeliveryResult
      attr_reader :provider_message_id, :idempotency_key

      def initialize(provider_message_id:, idempotency_key:)
        unless provider_message_id.is_a?(Integer) && provider_message_id.positive?
          raise InputError.new("bot.delivery.provider_message_id.invalid", "provider message id must be positive")
        end
        unless idempotency_key.is_a?(String) && idempotency_key.match?(/\A[^[:cntrl:]\s]{1,200}\z/)
          raise InputError.new("bot.delivery.idempotency_key.invalid", "idempotency key is invalid")
        end

        @provider_message_id = provider_message_id
        @idempotency_key = idempotency_key.dup.freeze
        freeze
      end
    end
  end
end
