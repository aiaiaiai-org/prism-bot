# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Channels
    module Telegram
      module Handlers
        class Publish
          def initialize(
            arguments_parser:,
            publish_publication:,
            message_sender:,
            presenter:,
            instance_id:,
            locale:,
            dispatch_policy:,
            voice_profile: nil
          )
            @arguments_parser = arguments_parser
            @publish_publication = publish_publication
            @message_sender = message_sender
            @presenter = presenter
            @instance_id = Domain::Publication.reference(instance_id, "instance_id")
            @locale = required_string(locale, "locale")
            @dispatch_policy = String(dispatch_policy).dup.freeze
            unless Domain::Publication::DISPATCH_POLICIES.include?(@dispatch_policy)
              raise ConfigurationError.new(
                "bot.dispatch_policy.invalid",
                "PRISM_BOT_DISPATCH_POLICY is unsupported"
              )
            end
            @voice_profile = optional_reference(voice_profile)
          end

          def call(update:, arguments:)
            parsed = @arguments_parser.parse(arguments)
            publication = build_publication(update, parsed)
            response = @publish_publication.call(
              publication: publication,
              idempotency_key: "telegram:#{@instance_id}:#{update.update_id}"
            )
            @message_sender.send_message(
              chat_id: update.chat_id,
              text: @presenter.published(response, target_count: publication.targets.length)
            )
          end

          private

          def build_publication(update, parsed)
            variant_id = "telegram.#{update.update_id}.post"
            variant = Domain::Publication::Variant.new(
              id: variant_id,
              locale: @locale,
              voice_profile: @voice_profile,
              format: "post",
              body: Domain::Publication::Body.new(text: parsed.text),
              provenance: Domain::Publication::Provenance.new(
                kind: "human",
                producer: "telegram",
                source_refs: ["telegram:update:#{update.update_id}"]
              )
            )
            targets = parsed.channel_ids.each_with_index.map do |channel_id, index|
              Domain::Publication::Target.new(
                id: "telegram.#{update.update_id}.target#{index + 1}",
                channel_id: channel_id,
                selection: Domain::Publication::Selection.exact(variant_id)
              )
            end
            Domain::Publication.new(
              dispatch_policy: @dispatch_policy,
              variants: [variant],
              targets: targets
            )
          end

          def required_string(value, field)
            string = String(value).strip
            return string.freeze unless string.empty?

            raise ConfigurationError.new("bot.configuration.empty", "#{field} must not be empty")
          end

          def optional_reference(value)
            return nil if value.nil? || String(value).strip.empty?

            Domain::Publication.reference(String(value).strip, "voice_profile")
          end
        end
      end
    end
  end
end
