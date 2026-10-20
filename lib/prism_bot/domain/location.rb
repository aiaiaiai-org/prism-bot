# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Domain
    # A position a person shared. It is passed on and never stored or logged by prism-bot.
    class Location
      attr_reader :latitude, :longitude

      def initialize(latitude:, longitude:, live: false)
        @latitude = coordinate(latitude, 90.0, "latitude")
        @longitude = coordinate(longitude, 180.0, "longitude")
        unless live == true || live == false
          raise InputError.new("bot.location.live.invalid", "location live flag must be true or false")
        end

        @live = live
        freeze
      end

      # The position is a live one that Telegram keeps updating while the person moves.
      def live?
        @live
      end

      private

      def coordinate(value, limit, name)
        number = Float(value)
        return number if number.finite? && number.abs <= limit

        raise InputError.new("bot.location.#{name}.invalid", "location #{name} is out of range")
      rescue ArgumentError, TypeError
        raise InputError.new("bot.location.#{name}.invalid", "location #{name} is not a number")
      end
    end
  end
end
