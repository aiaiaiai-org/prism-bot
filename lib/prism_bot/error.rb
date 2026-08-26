# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  class Error < StandardError
    attr_reader :code

    def initialize(code, message)
      super(message)
      @code = code
    end
  end

  class InputError < Error; end
  class ConfigurationError < Error; end
  class TransportError < Error; end
  class MessageDeliveryError < TransportError; end

  class HubError < Error
    attr_reader :http_status

    def initialize(code, message, http_status:)
      super(code, message)
      @http_status = http_status
    end
  end
end
