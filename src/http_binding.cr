require "http"
require "uri"

require "./event"
require "./decoder"
require "./encoder"
require "./decoder/json"
require "./encoder/json"

module CloudEvents
  struct HTTPBinding
    @types = {} of String => Proc(IO, Decoder, EventData)
    @decoders = {} of String => Proc(Decoder)

    def self.default
      new
        .register_decoder("application/json", CloudEvents::Decoder::JSON)
        .register_encoder("application/json", CloudEvents::Encoder::JSON)
    end

    def register_type(name, type : EventData.class) : self
      @types[name] = ->(io : IO, decoder : Decoder) { type.new(io, decoder).as(EventData) }
      self
    end

    def register_decoder(name, type : Decoder.class) : self
      @decoders[name] = ->{ type.new.as(Decoder) }
      self
    end

    def register_encoder(name, type : Encoder.class) : self
      self
    end

    def decode_event(context : HTTP::Server::Context, allow_opaque : Bool = false)
      decode_event context.request, allow_opaque: allow_opaque
    end

    def decode_event(request, allow_opaque : Bool = false)
      case request.method
      when /GET/i, /HEAD/i
        raise NotCloudEventError.new("Request method cannot be GET or HEAD")
      end

      if content_type_string = request.headers["content-type"]?
        content_type = ContentType.new(content_type_string)
      end

      content = case body = request.body
                in IO
                  body
                in String
                  IO::Memory.new(body)
                in Nil
                  return
                end

      if (type = @types[request.headers["ce-type"]?]?) && (decoder = @decoders[content_type_string]?)
        result = type.call(content, decoder.call)
      end

      if result
        Event::V1.new(
          data: result,
          id: request.headers.fetch("ce-id", ""),
          source: URI.parse(request.headers.fetch("ce-source", "")),
          spec_version: request.headers.fetch("ce-specversion", "1.0"),
          type: request.headers.fetch("ce-type", ""),
        )
      elsif !request.headers.has_key?("ce-specversion")
        raise NotCloudEventError.new("Content-Type is #{content_type_string}, and CE-SpecVersion is not present: #{request.headers.inspect}")
      end

      # if allow_opaque
      #   Event::Opaque.new
      # else
      #   Event::V1.new(
      #     data_encoded: "",
      #     data: "",
      #     id: "",
      #     source: "",
      #     specversion: "",
      #     type: "",
      #   )
      # end


    ensure
      # See https://github.com/crystal-lang/crystal/pull/11893
      if (body = request.body).is_a? IO
        body.skip_to_end
      end
    end

    def encode_event(uri : URI, event : Event)
      headers = HTTP::Headers{
        "connection" => "keep-alive",
      }
      # Required
      # https://github.com/cloudevents/spec/blob/9b3a3c94497bdc2c4437a52b2e353c8c4b9003cb/cloudevents/spec.md#required-attributes
      headers["ce-id"] = event.id
      headers["ce-source"] = event.source.to_s
      headers["ce-specversion"] = event.spec_version
      headers["ce-type"] = event.type

      # Optional attributes
      # https://github.com/cloudevents/spec/blob/9b3a3c94497bdc2c4437a52b2e353c8c4b9003cb/cloudevents/spec.md#optional-attributes
      if content_type = event.data_content_type.presence
        headers["content-type"] = content_type
      end
      if schema = event.data_schema.presence
        headers["ce-dataschema"] = schema
      end
      if subject = event.subject.presence
        headers["ce-subject"] = subject
      end
      # This is guaranteed to be populated
      headers["ce-time"] = event.time.to_rfc3339(fraction_digits: 9)

      # TODO: Use the encoder for this
      body = event.data.to_json

      HTTP::Request.new(
        method: "POST",
        resource: uri.path,
        headers: headers,
        body: body,
      )
    end

    def percent_encode(str)
      URI.encode_www_form(str, space_to_plus: false)
    end

    def percent_decode(input)
      bytes = Bytes.new(input.bytesize)
      index = 0
      inside_quotes = false
      backslash = false
      chars = input.each_char

      loop do
        c = chars.next
        case c
        when Iterator::Stop
          break
        when '%'
          high_nybble = chars.next
          low_nybble = chars.next
          case {high_nybble, low_nybble}
          when {Char, Char}
            if (high = high_nybble.to_u8?(16)) && (low = low_nybble.to_u8?(16))
              bytes[index] = high * 16 + low
            else
              {c, high_nybble, low_nybble}.each(&.each_byte do |byte|
                bytes[index] = byte
                index += 1
              end)
              next
            end
          when {Char, Iterator::Stop}
            {c, high_nybble}.each(&.each_byte do |byte|
              bytes[index] = byte
              index += 1
            end)
            next
          else
            raise "This should never happen"
          end
        when '\\'
          if backslash
            c.each_byte do |byte|
              bytes[index] = byte
            end
          else
            backslash = true
            next
          end
        when '"'
          if backslash
            c.each_byte do |byte|
              bytes[index] = byte
              index += 1
            end
            backslash = false
            next
          else
            inside_quotes = !inside_quotes
            next
          end
        else
          c.each_byte do |byte|
            bytes[index] = byte
            index += 1
          end
          backslash = false
          next
        end

        index += 1
        backslash = false
      end

      String.new(bytes[0, index])
    end

    private def decode_binary_content(
      content : Bytes,
      content_type : ContentType?,
      request : HTTP::Request,
      legacy_data_encode : Bool
    )
    end

    private def decode_structured_content(
      content : Bytes,
      content_type : ContentType?,
      allow_opaque : Bool,
      **format_args
    )
      result = @event_decoders.decode_event(
        **format_args,
        content: content,
        content_type: content_type,
        data_decoder: @data_decoders,
      )
      return result[:event] || result[:event_batch] if result
      if content_type.try(&.media_type) == "application" &&
         {"cloudevents", "cloudevents-batch"}.includes?(content_type.subtype_base)
        return Event::Opaque.new content, content_type if allow_opaque
        raise UnsupportedFormatError, "Unknown cloudevents content type: #{content_type}"
      end
      nil
    end
  end
end
