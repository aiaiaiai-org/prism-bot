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
    attr_reader :http_status, :request_id

    def initialize(code, message, http_status:, request_id: nil)
      super(code, message)
      @http_status = http_status
      @request_id = request_id&.dup&.freeze
    end
  end
end
