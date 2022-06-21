module CloudEvents
  module Encoder
    abstract def call(event : Event)
  end
end
