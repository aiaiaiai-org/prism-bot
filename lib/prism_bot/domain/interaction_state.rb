# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Domain
    class InteractionState
      NAME_PATTERN = /\A[a-z][a-z0-9_.-]{0,63}\z/

      attr_reader :name, :data

      def initialize(name:, data: {})
        @name = normalize_name(name)
        @data = deep_copy_and_freeze(data)
        freeze
      end

      private

      def normalize_name(value)
        string = String(value)
        return string.dup.freeze if NAME_PATTERN.match?(string)

        raise InputError.new(
          "bot.interaction.state.invalid",
          "interaction state name is invalid"
        )
      end

      def deep_copy_and_freeze(value)
        case value
        when Hash
          value.to_h.each_with_object({}) do |(key, item), result|
            result[String(key).dup.freeze] = deep_copy_and_freeze(item)
          end.freeze
        when Array
          value.map { deep_copy_and_freeze(_1) }.freeze
        when String
          value.dup.freeze
        when Integer, Float, TrueClass, FalseClass, NilClass
          value
        else
          raise InputError.new(
            "bot.interaction.state.data.invalid",
            "interaction state data must contain JSON-compatible values"
          )
        end
      end
    end
  end
end
