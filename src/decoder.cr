module CloudEvents
  module Decoder
    abstract def call(io : IO, as type : T.class) forall T
  end
end
