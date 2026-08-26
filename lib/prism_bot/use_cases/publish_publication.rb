# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module UseCases
    class PublishPublication
      def initialize(publication_publisher:)
        @publication_publisher = publication_publisher
      end

      def call(publication:, idempotency_key:)
        unless publication.is_a?(Domain::Publication)
          raise InputError.new(
            "bot.publication.invalid",
            "publication must be an immutable Publication value"
          )
        end

        @publication_publisher.publish(
          publication: publication,
          idempotency_key: idempotency_key
        )
      end
    end
  end
end
