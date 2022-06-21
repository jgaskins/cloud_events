require "json"

require "../encoder"

struct CloudEvents::Encoder::JSON
  include Encoder

  def call(event : Event)
    event.to_json
  end
end
