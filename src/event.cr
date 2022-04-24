require "./errors"

module CloudEvents
  struct ContentType
    getter type, charset

    def initialize(@type : String, @charset : String = "us-ascii")
    end
  end

  module Event
      abstract def batch? : Bool
      abstract def content
      abstract def content_type : ContentType

    # struct Opaque(T)
    #   include Event(T)

    #   def batch? : Bool
    #     false
    #   end

    #   def content
    #   end

    #   def content_type : ContentType
    #     ContentType.new("opaque?")
    #   end
    # end

    struct V1
      include Event

      getter data_encoded, data, data_content_type, data_schema, id, source, spec_version, subject, time, trace_context, type

      def initialize(
        *,
        @data_encoded : String,
        @data : EventData,
        @data_content_type : String = "",
        @data_schema : String = "",
        @id : String,
        @source : URI,
        @spec_version : String,
        @subject : String = "",
        @time : Time = Time.new(seconds: 0i64, nanoseconds: 0, location: Time::Location::UTC),
        @trace_context : String = "",
        @type : String
      )
      end

      def batch? : Bool
        false
      end

      def content
      end

      def content_type : ContentType
        ContentType.new("asdf")
      end
    end
  end
end
