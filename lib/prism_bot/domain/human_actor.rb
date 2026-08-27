# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Domain
    class HumanActor
      ROLES = %w[owner admin member].freeze

      attr_reader :canonical_id, :role

      def initialize(canonical_id:, role:)
        @canonical_id = normalize_id(canonical_id)
        @role = normalize_role(role)
        freeze
      end

      def canonical_type
        "person"
      end

      def canonical_ref
        "person:#{canonical_id}"
      end

      private

      def normalize_id(value)
        string = String(value)
        return string.dup.freeze if !string.empty? && string.length <= 255

        raise InputError.new(
          "bot.actor.identity.invalid",
          "resolved actor identity must contain 1 to 255 characters"
        )
      end

      def normalize_role(value)
        string = String(value)
        return string.dup.freeze if ROLES.include?(string)

        raise InputError.new(
          "bot.actor.role.invalid",
          "resolved actor role is invalid"
        )
      end
    end
  end
end
