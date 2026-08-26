# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Adapters
    class NetHttpTransport
      Response = Struct.new(:status, :body, keyword_init: true)

      def initialize(
        allow_insecure_http: false,
        open_timeout_seconds: 5,
        read_timeout_seconds: 15,
        max_response_bytes: 1_048_576
      )
        @allow_insecure_http = allow_insecure_http
        @open_timeout_seconds = open_timeout_seconds
        @read_timeout_seconds = read_timeout_seconds
        @max_response_bytes = max_response_bytes
      end

      def call(method:, url:, headers:, body: nil)
        uri = URI.parse(url)
        validate_uri!(uri)
        request = Net::HTTPGenericRequest.new(
          method,
          !body.nil?,
          true,
          uri.request_uri,
          headers
        )
        request.body = body if body

        response_body = +""
        status = nil
        http(uri).request(request) do |response|
          status = response.code.to_i
          response.read_body do |chunk|
            if response_body.bytesize + chunk.bytesize > @max_response_bytes
              raise TransportError.new(
                "bot.http.response.too_large",
                "upstream response exceeded the configured limit"
              )
            end
            response_body << chunk
          end
        end
        Response.new(status: status, body: response_body.freeze).freeze
      rescue URI::InvalidURIError
        raise ConfigurationError.new("bot.http.url.invalid", "upstream URL is invalid")
      rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, EOFError
        raise TransportError.new(
          "bot.http.unavailable",
          "upstream service is unavailable"
        )
      end

      private

      def validate_uri!(uri)
        valid = uri.host && uri.path && (uri.scheme == "https" || (@allow_insecure_http && uri.scheme == "http"))
        return if valid

        raise ConfigurationError.new(
          "bot.http.url.insecure",
          "upstream URL must use HTTPS unless insecure HTTP is explicitly enabled"
        )
      end

      def http(uri)
        Net::HTTP.new(uri.host, uri.port).tap do |client|
          client.use_ssl = uri.scheme == "https"
          client.open_timeout = @open_timeout_seconds
          client.read_timeout = @read_timeout_seconds
        end
      end
    end
  end
end
