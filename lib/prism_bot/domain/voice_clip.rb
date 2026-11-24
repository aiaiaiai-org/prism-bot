# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Domain
    # Audio to be sent as a native voice message. Only Ogg/Opus is accepted: other formats may reach
    # the person as an audio file or a document instead of a playable voice message.
    class VoiceClip
      # Telegram bots can currently send voice messages of up to 50 MB.
      MAX_BYTES = 50 * 1024 * 1024
      OGG_MAGIC = "OggS".b.freeze
      OPUS_MAGIC = "OpusHead".b.freeze
      OPUS_HEADER_WINDOW = 128

      attr_reader :audio, :duration_seconds

      def initialize(audio:, duration_seconds:)
        unless audio.is_a?(String) && (1..MAX_BYTES).cover?(audio.bytesize)
          raise InputError.new("bot.voice.audio.invalid", "voice audio is empty or too large")
        end
        data = audio.b
        unless data.start_with?(OGG_MAGIC) && data.byteslice(0, OPUS_HEADER_WINDOW).include?(OPUS_MAGIC)
          raise InputError.new("bot.voice.audio.format", "voice audio must be Ogg/Opus")
        end
        unless duration_seconds.is_a?(Integer) && duration_seconds.positive?
          raise InputError.new("bot.voice.duration.invalid", "voice duration must be positive whole seconds")
        end

        @audio = data.freeze
        @duration_seconds = duration_seconds
        freeze
      end
    end
  end
end
