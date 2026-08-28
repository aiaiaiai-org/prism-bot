# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Domain
    class BotLifecycleState
      STATUSES = %w[active paused disabled].freeze

      attr_reader :status

      def initialize(status:)
        value = String(status)
        unless STATUSES.include?(value)
          raise InputError.new(
            "bot.lifecycle.status.invalid",
            "bot lifecycle status is invalid"
          )
        end

        @status = value.freeze
        freeze
      end

      def active?
        status == "active"
      end

      def paused?
        status == "paused"
      end

      def disabled?
        status == "disabled"
      end
    end
  end
end
