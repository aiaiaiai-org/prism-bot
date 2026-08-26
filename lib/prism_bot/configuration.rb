# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  class Configuration
    TRUE_VALUES = %w[1 true yes].freeze
    FALSE_VALUES = %w[0 false no].freeze

    attr_reader :instance_id,
      :telegram_token,
      :telegram_webhook_secret,
      :allowed_user_ids,
      :allowed_chat_ids,
      :default_channel_ids,
      :default_locale,
      :default_voice_profile,
      :dispatch_policy,
      :hub_base_url,
      :hub_api_token,
      :max_webhook_bytes,
      :allow_insecure_http

    def initialize(environment)
      @instance_id = required(environment, "PRISM_BOT_INSTANCE_ID")
      @telegram_token = required(environment, "PRISM_BOT_TELEGRAM_TOKEN")
      @telegram_webhook_secret = required(
        environment,
        "PRISM_BOT_TELEGRAM_WEBHOOK_SECRET"
      )
      @allowed_user_ids = integer_array(environment, "PRISM_BOT_TELEGRAM_ALLOWED_USER_IDS")
      @allowed_chat_ids = integer_array(environment, "PRISM_BOT_TELEGRAM_ALLOWED_CHAT_IDS")
      @default_channel_ids = string_array(environment, "PRISM_BOT_DEFAULT_CHANNEL_IDS")
      @default_locale = environment.fetch("PRISM_BOT_DEFAULT_LOCALE", "uk-UA").strip.freeze
      @default_voice_profile = optional(environment["PRISM_BOT_DEFAULT_VOICE_PROFILE"])
      @dispatch_policy = String(environment.fetch(
        "PRISM_BOT_DISPATCH_POLICY",
        "require_all_valid"
      )).dup.freeze
      @hub_base_url = required(environment, "PRISM_HUB_BASE_URL")
      @hub_api_token = required(environment, "PRISM_HUB_API_TOKEN")
      @max_webhook_bytes = positive_integer(
        environment.fetch("PRISM_BOT_MAX_WEBHOOK_BYTES", "1048576"),
        "PRISM_BOT_MAX_WEBHOOK_BYTES"
      )
      @allow_insecure_http = boolean(
        environment.fetch("PRISM_BOT_ALLOW_INSECURE_HTTP", "false"),
        "PRISM_BOT_ALLOW_INSECURE_HTTP"
      )
      freeze
    end

    private

    def required(environment, name)
      value = String(environment.fetch(name)).strip
      return value.freeze unless value.empty?

      raise ConfigurationError.new("bot.configuration.missing", "#{name} must not be empty")
    rescue KeyError
      raise ConfigurationError.new("bot.configuration.missing", "#{name} is required")
    end

    def optional(value)
      return nil if value.nil? || String(value).strip.empty?

      String(value).strip.freeze
    end

    def integer_array(environment, name)
      json_array(environment.fetch(name, "[]"), name).map do |value|
        Integer(value)
      end.uniq.sort.freeze
    rescue ArgumentError, TypeError
      raise ConfigurationError.new(
        "bot.configuration.integer_array.invalid",
        "#{name} must be a JSON array of integers"
      )
    end

    def string_array(environment, name)
      json_array(environment.fetch(name, "[]"), name).map do |value|
        string = String(value).strip
        if string.empty?
          raise ConfigurationError.new(
            "bot.configuration.string_array.invalid",
            "#{name} must not contain empty values"
          )
        end
        string.freeze
      end.uniq.freeze
    end

    def json_array(source, name)
      value = JSON.parse(source)
      return value if value.is_a?(Array)

      raise ConfigurationError.new("bot.configuration.array.invalid", "#{name} must be a JSON array")
    rescue JSON::ParserError
      raise ConfigurationError.new("bot.configuration.json.invalid", "#{name} must be valid JSON")
    end

    def positive_integer(source, name)
      value = Integer(source)
      return value if value.positive?

      raise ArgumentError
    rescue ArgumentError, TypeError
      raise ConfigurationError.new("bot.configuration.integer.invalid", "#{name} must be positive")
    end

    def boolean(source, name)
      normalized = String(source).downcase
      return true if TRUE_VALUES.include?(normalized)
      return false if FALSE_VALUES.include?(normalized)

      raise ConfigurationError.new(
        "bot.configuration.boolean.invalid",
        "#{name} must be true or false"
      )
    end
  end
end
