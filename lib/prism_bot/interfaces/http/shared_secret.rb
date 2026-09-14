# © 2026 aiaiaiai · aiaiaiai.org
# SPDX-License-Identifier: Apache-2.0

module PrismBot
  module Interfaces
    module HTTP
      class SharedSecret
        PATTERN = /\A[A-Za-z0-9_-]{32,256}\z/

        def initialize(value, code: "bot.http.secret.invalid")
          @value = String(value).dup.freeze
          return if PATTERN.match?(@value)

          raise ConfigurationError.new(
            code,
            "HTTP shared secret must contain 32-256 permitted characters"
          )
        end

        def valid?(candidate)
          candidate.is_a?(String) && Rack::Utils.secure_compare(candidate, @value)
        end
      end
    end
  end
end
