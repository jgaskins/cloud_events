module CloudEvents
  module Decoder
    abstract def call(io : IO, as type : T.class) forall T

    struct JSON
      include Decoder

      def call(io : IO, as type : T.class) forall T
        T.from_json(io)
      end
    end
  end
end
