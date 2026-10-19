# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Domain
    class AlertSubscription
      CELL_PATTERN = /\A86[0-9a-f]{13}\z/
      CATEGORIES = %w[drone bomb missile].freeze

      attr_reader :cell, :categories

      def initialize(cell:, categories:, include_nearby:)
        @cell = normalize_cell(cell)
        @categories = normalize_categories(categories)
        @include_nearby = normalize_flag(include_nearby)
        freeze
      end

      def include_nearby?
        @include_nearby
      end

      def to_h
        {
          cell: cell,
          categories: categories,
          include_nearby: include_nearby?
        }
      end

      private

      def normalize_cell(value)
        string = String(value)
        return string.dup.freeze if string.match?(CELL_PATTERN)

        raise InputError.new(
          "bot.alerts.cell.invalid",
          "alert cell must be an H3 resolution 6 cell"
        )
      end

      def normalize_categories(values)
        list = Array(values).map { String(_1) }
        valid = !list.empty? && list.uniq.length == list.length && (list - CATEGORIES).empty?
        return list.map { _1.dup.freeze }.freeze if valid

        raise InputError.new(
          "bot.alerts.categories.invalid",
          "alert categories must be a non-empty unique set of known kinds"
        )
      end

      def normalize_flag(value)
        return value if value == true || value == false

        raise InputError.new(
          "bot.alerts.nearby.invalid",
          "include_nearby must be true or false"
        )
      end
    end
  end
end
