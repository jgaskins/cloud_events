require "json"

require "../decoder"

struct CloudEvents::Decoder::JSON
  include Decoder

  def call(io : IO, as type : T.class) forall T
    T.from_json(io)
  end
end
