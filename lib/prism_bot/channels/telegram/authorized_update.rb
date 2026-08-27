# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      class AuthorizedUpdate
        attr_reader :update, :actor

        def initialize(update:, actor:)
          unless update.is_a?(Update)
            raise ArgumentError, "update must be a Telegram::Update"
          end
          unless actor.is_a?(Domain::HumanActor)
            raise ArgumentError, "actor must be a HumanActor"
          end

          @update = update
          @actor = actor
          freeze
        end

        def update_id
          update.update_id
        end

        def chat_id
          update.chat_id
        end

        def user_id
          update.user_id
        end

        def text
          update.text
        end
      end
    end
  end
end
