# © 2026 aiaiaiai · aiaiaiai.org

module PrismBot
  module Adapters
    module Telegram
      # Ephemeral messages and native voice messages over the Telegram Bot API (10.2 or later; the
      # parameters below follow 10.5): sendMessage, sendVoice and editEphemeralMessageText with
      # ephemeral_message_parameters.
      #
      # Privacy is checked, not assumed. A success response is accepted as an ephemeral delivery only
      # if it names an ephemeral message id, a zero message id and the intended receiver. Anything
      # else is raised as an error, and nothing is ever re-sent as a public message.
      class EphemeralBotApiClient
        include Ports::EphemeralMessageSender
        include Ports::VoiceSender
        include ApiSupport

        MAX_TEXT_CHARACTERS = 4_096
        MAX_CAPTION_CHARACTERS = 1_024
        VOICE_FILENAME = "voice.ogg".freeze
        VOICE_CONTENT_TYPE = "audio/ogg".freeze

        EPHEMERAL_REJECTED = ["bot.telegram.ephemeral.rejected", "Telegram rejected the ephemeral message"].freeze
        VOICE_REJECTED = ["bot.telegram.voice.rejected", "Telegram rejected the voice message"].freeze

        def initialize(token:, transport:)
          @send_message_url = api_url(token, "sendMessage")
          @send_voice_url = api_url(token, "sendVoice")
          @edit_text_url = api_url(token, "editEphemeralMessageText")
          @transport = transport
        end

        def send_ephemeral_message(target:, text:, reply_markup: nil)
          validate_target!(target)
          validate_text!(text, MAX_TEXT_CHARACTERS, "bot.telegram.ephemeral.text.invalid")
          payload = ephemeral_fields(target).merge("text" => text)
          payload["reply_markup"] = inline_markup(reply_markup) if reply_markup

          value = post_json(@send_message_url, payload, EPHEMERAL_REJECTED)
          confirm_ephemeral!(value["result"], target)
        end

        def edit_ephemeral_message(ref:, text:, reply_markup: nil)
          unless ref.is_a?(Domain::EphemeralMessageRef)
            raise InputError.new("bot.telegram.ephemeral.ref.invalid", "ephemeral message reference is invalid")
          end
          validate_text!(text, MAX_TEXT_CHARACTERS, "bot.telegram.ephemeral.text.invalid")
          payload = {
            "chat_id" => ref.chat_id,
            "receiver_user_id" => ref.receiver_user_id,
            "ephemeral_message_id" => ref.ephemeral_message_id,
            "text" => text
          }
          payload["reply_markup"] = inline_markup(reply_markup) if reply_markup

          value = post_json(@edit_text_url, payload, EPHEMERAL_REJECTED)
          return nil if value["result"] == true

          raise MessageDeliveryError.new("bot.telegram.ephemeral.unconfirmed", "Telegram did not confirm the edit")
        end

        def send_ephemeral_voice(target:, clip:, caption:)
          validate_target!(target)
          validate_voice!(clip, caption)
          fields = ephemeral_fields(target).merge(voice_fields(clip, caption))

          value = post_voice(fields, clip)
          result = value["result"]
          file_id = confirm_voice!(result)
          ref = confirm_ephemeral!(result, target)
          Domain::VoiceReceipt.new(file_id: file_id, ephemeral_ref: ref)
        end

        def send_public_voice(chat_id:, clip:, caption:, message_thread_id: nil)
          unless chat_id.is_a?(Integer) && !chat_id.zero?
            raise InputError.new("bot.telegram.voice.chat.invalid", "voice chat is invalid")
          end
          unless message_thread_id.nil? || (message_thread_id.is_a?(Integer) && message_thread_id.positive?)
            raise InputError.new("bot.telegram.surface.thread.invalid", "Telegram topic is invalid")
          end
          validate_voice!(clip, caption)
          fields = {"chat_id" => chat_id}
          fields["message_thread_id"] = message_thread_id if message_thread_id
          fields.merge!(voice_fields(clip, caption))

          result = post_voice(fields, clip)["result"]
          file_id = confirm_voice!(result)
          message_id = result["message_id"]
          confirmed_chat = result["chat"].is_a?(Hash) ? result["chat"]["id"] : chat_id
          # A public voice has a real message id and is not ephemeral; anything else is not what was asked.
          unless message_id.is_a?(Integer) && message_id.positive? && !result.key?("ephemeral_message_id") &&
              confirmed_chat == chat_id
            raise MessageDeliveryError.new("bot.telegram.voice.unconfirmed", "Telegram did not confirm the voice message")
          end

          Domain::VoiceReceipt.new(file_id: file_id, message_id: message_id)
        end

        private

        def validate_target!(target)
          return if target.is_a?(Domain::EphemeralTarget)

          raise InputError.new("bot.telegram.ephemeral.target.invalid", "ephemeral target is invalid")
        end

        def validate_text!(text, limit, code)
          return if text.is_a?(String) && (1..limit).cover?(text.length) && !text.strip.empty?

          # Never shortened: a private message that was cut short would misreport what was said.
          raise InputError.new(code, "message text is empty or longer than #{limit} characters")
        end

        def validate_voice!(clip, caption)
          unless clip.is_a?(Domain::VoiceClip)
            raise InputError.new("bot.telegram.voice.clip.invalid", "voice clip is invalid")
          end

          validate_text!(caption, MAX_CAPTION_CHARACTERS, "bot.telegram.voice.caption.invalid")
        end

        # Where the message goes and why the bot may send it; see Domain::EphemeralTarget.
        def ephemeral_fields(target)
          fields = {"chat_id" => target.chat_id}
          fields["message_thread_id"] = target.message_thread_id if target.message_thread_id
          case target.mode
          when :callback
            fields["ephemeral_message_parameters"] = {"callback_query_id" => target.callback_query_id}
          when :reply
            fields["ephemeral_message_parameters"] = {"receiver_user_id" => target.receiver_user_id}
            fields["reply_parameters"] = {"ephemeral_message_id" => target.reply_ephemeral_message_id}
          else
            fields["ephemeral_message_parameters"] = {"receiver_user_id" => target.receiver_user_id}
          end
          fields
        end

        def voice_fields(clip, caption)
          {"caption" => caption, "duration" => clip.duration_seconds}
        end

        def inline_markup(keyboard)
          unless keyboard.is_a?(Domain::InlineKeyboard)
            raise InputError.new("bot.telegram.keyboard.invalid", "inline keyboard is invalid")
          end

          {
            "inline_keyboard" => keyboard.rows.map do |row|
              row.map { |button| {"text" => button.text, "callback_data" => button.callback_data} }
            end
          }
        end

        def confirm_ephemeral!(result, target)
          fail_unconfirmed! unless result.is_a?(Hash)

          id = result["ephemeral_message_id"]
          message_id = result["message_id"]
          receiver = result["receiver_user"].is_a?(Hash) ? result["receiver_user"]["id"] : nil
          chat = result["chat"].is_a?(Hash) ? result["chat"]["id"] : target.chat_id
          confirmed = id.is_a?(Integer) && id.positive? && (message_id.nil? || message_id == 0) &&
            receiver == target.receiver_user_id && chat == target.chat_id
          fail_unconfirmed! unless confirmed

          Domain::EphemeralMessageRef.new(
            chat_id: target.chat_id,
            receiver_user_id: target.receiver_user_id,
            ephemeral_message_id: id
          )
        end

        def fail_unconfirmed!
          raise MessageDeliveryError.new(
            "bot.telegram.ephemeral.unconfirmed",
            "Telegram did not confirm private delivery"
          )
        end

        # The result must be a native voice message, not an audio file or a document.
        def confirm_voice!(result)
          voice = result["voice"] if result.is_a?(Hash)
          file_id = voice["file_id"] if voice.is_a?(Hash)
          return file_id if file_id.is_a?(String) && !file_id.empty?

          raise MessageDeliveryError.new("bot.telegram.voice.unconfirmed", "Telegram did not confirm a voice message")
        end

        def post_json(url, payload, failure)
          perform(
            url,
            {"accept" => "application/json", "content-type" => "application/json"},
            JSON.generate(payload),
            failure
          )
        end

        def post_voice(fields, clip)
          boundary = "prism-bot-#{SecureRandom.hex(16)}"
          perform(
            @send_voice_url,
            {"accept" => "application/json", "content-type" => "multipart/form-data; boundary=#{boundary}"},
            multipart_body(fields, clip, boundary),
            VOICE_REJECTED
          )
        end

        # Structured fields travel as JSON text, as the Bot API expects for multipart requests.
        def multipart_body(fields, clip, boundary)
          body = String.new(encoding: Encoding::BINARY)
          fields.each do |name, value|
            text = value.is_a?(String) ? value : (value.is_a?(Integer) ? value.to_s : JSON.generate(value))
            body << "--#{boundary}\r\n".b
            body << %(Content-Disposition: form-data; name="#{name}"\r\n\r\n).b
            body << text.b << "\r\n".b
          end
          body << "--#{boundary}\r\n".b
          body << %(Content-Disposition: form-data; name="voice"; filename="#{VOICE_FILENAME}"\r\n).b
          body << "Content-Type: #{VOICE_CONTENT_TYPE}\r\n\r\n".b
          body << clip.audio << "\r\n".b
          body << "--#{boundary}--\r\n".b
        end

        def perform(url, headers, body, failure)
          response = @transport.call(method: "POST", url: url, headers: headers, body: body)
          value = parse_response(response.body)
          return value if response.status == 200 && value["ok"] == true

          raise_delivery_error(response.status, value, code: failure[0], message: failure[1])
        rescue TransportError => error
          raise error if error.is_a?(MessageDeliveryError)

          raise MessageDeliveryError.new("bot.telegram.unavailable", "Telegram is unavailable")
        end
      end
    end
  end
end
