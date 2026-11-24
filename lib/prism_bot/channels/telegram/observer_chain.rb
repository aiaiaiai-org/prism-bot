# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      # Hands each observation to every observer. An observer that fails is logged by class name only
      # (never its message, which may hold chat content) and cannot stop the others or the webhook.
      class ObserverChain
        def initialize(observers:, logger:)
          @observers = observers.dup.freeze
          @logger = logger
        end

        def call(observation)
          @observers.each do |observer|
            observer.call(observation)
          rescue StandardError => error
            @logger.error("telegram_webhook observer_failed class=#{error.class.name}")
          end
          nil
        end
      end
    end
  end
end
