# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Domain
    class InteractionKey
      attr_reader :instance_id, :surface, :actor_ref

      def initialize(instance_id:, surface:, actor_ref:)
        @instance_id = normalize(instance_id, "instance_id")
        @surface = normalize(surface, "surface")
        @actor_ref = normalize(actor_ref, "actor_ref")
        freeze
      end

      def ==(other)
        other.is_a?(InteractionKey) &&
          instance_id == other.instance_id &&
          surface == other.surface &&
          actor_ref == other.actor_ref
      end
      alias eql? ==

      def hash
        [instance_id, surface, actor_ref].hash
      end

      private

      def normalize(value, field)
        string = String(value).strip
        return string.dup.freeze if !string.empty? && string.length <= 255

        raise InputError.new(
          "bot.interaction.key.invalid",
          "#{field} must contain 1 to 255 characters"
        )
      end
    end
  end
end
