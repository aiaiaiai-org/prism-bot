# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Domain
    class Publication
      REFERENCE_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9._:-]{0,127}\z/
      DISPATCH_POLICIES = %w[independent require_all_valid].freeze

      class Media
        KINDS = %w[audio document image video].freeze

        def initialize(reference:, kind:, mime_type: nil, alt_text: nil)
          @reference = Publication.reference(reference, "media.ref")
          @kind = String(kind).dup.freeze
          raise InputError.new("bot.media.kind.invalid", "unsupported media kind") unless KINDS.include?(@kind)

          @mime_type = optional_string(mime_type)
          @alt_text = optional_string(alt_text)
          freeze
        end

        def to_h
          value = {"ref" => @reference, "kind" => @kind}
          value["mime_type"] = @mime_type if @mime_type
          value["alt_text"] = @alt_text if @alt_text
          value
        end

        private

        def optional_string(value)
          return nil if value.nil?

          string = String(value).strip
          return string.freeze unless string.empty?

          raise InputError.new("bot.media.value.empty", "media metadata must not be empty")
        end
      end

      class Body
        def initialize(text: nil, media: [])
          @text = normalize_text(text)
          @media = Array(media).dup.freeze
          unless @media.all? { _1.is_a?(Media) }
            raise InputError.new("bot.body.media.invalid", "body media must contain Media values")
          end
          if @text.nil? && @media.empty?
            raise InputError.new("bot.body.empty", "publication body must contain text or media")
          end

          freeze
        end

        def to_h
          value = {}
          value["text"] = @text if @text
          value["media"] = @media.map(&:to_h) if @media.any?
          value
        end

        private

        def normalize_text(value)
          return nil if value.nil?

          string = String(value).strip
          return string.freeze unless string.empty?

          raise InputError.new("bot.body.text.empty", "publication text must not be empty")
        end
      end

      class Provenance
        KINDS = %w[ai deterministic_transform human import].freeze

        def initialize(kind:, producer: nil, source_refs: [])
          @kind = String(kind).dup.freeze
          raise InputError.new("bot.provenance.kind.invalid", "unsupported provenance kind") unless KINDS.include?(@kind)

          @producer = producer.nil? ? nil : String(producer).dup.freeze
          @source_refs = Array(source_refs).map { String(_1).dup.freeze }.freeze
          freeze
        end

        def to_h
          value = {"kind" => @kind}
          value["producer"] = @producer if @producer
          value["source_refs"] = @source_refs if @source_refs.any?
          value
        end
      end

      class Variant
        FORMATS = %w[poll post short_video story].freeze

        attr_reader :id

        def initialize(id:, locale:, format:, body:, provenance:, voice_profile: nil)
          @id = Publication.reference(id, "variant.id")
          @locale = required_string(locale, "variant.locale")
          @format = String(format).dup.freeze
          raise InputError.new("bot.variant.format.invalid", "unsupported publication format") unless FORMATS.include?(@format)
          raise InputError.new("bot.variant.body.invalid", "body must be a Body value") unless body.is_a?(Body)
          raise InputError.new("bot.variant.provenance.invalid", "provenance must be a Provenance value") unless provenance.is_a?(Provenance)

          @body = body
          @provenance = provenance
          @voice_profile = voice_profile.nil? ? nil : Publication.reference(
            voice_profile,
            "variant.voice_profile"
          )
          freeze
        end

        def to_h
          value = {
            "id" => @id,
            "locale" => @locale,
            "format" => @format,
            "body" => @body.to_h,
            "provenance" => @provenance.to_h
          }
          value["voice_profile"] = @voice_profile if @voice_profile
          value
        end

        private

        def required_string(value, field)
          string = String(value).strip
          return string.freeze unless string.empty?

          raise InputError.new("bot.value.empty", "#{field} must not be empty")
        end
      end

      class Selection
        attr_reader :variant_ids

        def self.exact(variant_id)
          new(mode: "exact", variant_ids: [variant_id])
        end

        def self.ordered(variant_ids)
          new(mode: "ordered", variant_ids: variant_ids)
        end

        def initialize(mode:, variant_ids:)
          @mode = String(mode).dup.freeze
          @variant_ids = Array(variant_ids).map do |variant_id|
            Publication.reference(variant_id, "selection.variant_id")
          end
          if @variant_ids.empty? || @variant_ids.uniq.length != @variant_ids.length
            raise InputError.new(
              "bot.selection.invalid",
              "selection requires unique variant ids"
            )
          end
          unless %w[exact ordered].include?(@mode)
            raise InputError.new("bot.selection.mode.invalid", "unsupported selection mode")
          end
          if @mode == "exact" && @variant_ids.length != 1
            raise InputError.new("bot.selection.exact.invalid", "exact selection requires one variant")
          end

          @variant_ids.freeze
          freeze
        end

        def to_h
          return {"mode" => "exact", "variant_id" => @variant_ids.first} if @mode == "exact"

          {"mode" => "ordered", "variant_ids" => @variant_ids}
        end
      end

      class Target
        attr_reader :id, :selection

        def initialize(id:, channel_id:, selection:)
          @id = Publication.reference(id, "target.id")
          @channel_id = Publication.reference(channel_id, "target.channel_id")
          unless selection.is_a?(Selection)
            raise InputError.new("bot.target.selection.invalid", "selection must be a Selection value")
          end

          @selection = selection
          freeze
        end

        def to_h
          {
            "id" => @id,
            "channel_id" => @channel_id,
            "selection" => @selection.to_h
          }
        end
      end

      attr_reader :variants, :targets

      def self.reference(value, field)
        string = String(value).dup
        return string.freeze if REFERENCE_PATTERN.match?(string)

        raise InputError.new("bot.reference.invalid", "#{field} must be a stable reference")
      end

      def initialize(dispatch_policy:, variants:, targets:)
        @dispatch_policy = String(dispatch_policy).dup.freeze
        unless DISPATCH_POLICIES.include?(@dispatch_policy)
          raise InputError.new("bot.dispatch_policy.invalid", "unsupported dispatch policy")
        end

        @variants = typed_non_empty_array(variants, Variant, "variants")
        @targets = typed_non_empty_array(targets, Target, "targets")
        ensure_unique!(@variants.map(&:id), "variant")
        ensure_unique!(@targets.map(&:id), "target")
        ensure_selections_reference_variants!
        freeze
      end

      def to_h
        {
          "dispatch_policy" => @dispatch_policy,
          "variants" => @variants.map(&:to_h),
          "targets" => @targets.map(&:to_h)
        }
      end

      private

      def typed_non_empty_array(values, type, field)
        items = Array(values).dup
        if items.empty? || !items.all? { _1.is_a?(type) }
          raise InputError.new("bot.publication.#{field}.invalid", "#{field} must contain #{type.name} values")
        end

        items.freeze
      end

      def ensure_unique!(ids, subject)
        return if ids.uniq.length == ids.length

        raise InputError.new("bot.publication.#{subject}_id.duplicate", "#{subject} ids must be unique")
      end

      def ensure_selections_reference_variants!
        variant_ids = @variants.map(&:id)
        missing = @targets.flat_map { _1.selection.variant_ids }.uniq - variant_ids
        return if missing.empty?

        raise InputError.new(
          "bot.publication.selection.unknown_variant",
          "target selections must reference declared variants"
        )
      end
    end
  end
end
