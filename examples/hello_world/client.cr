require "http"
require "../../src/http_binding"
require "../../src/decoder/json"
require "../../src/encoder/json"

http_binding = CloudEvents::HTTPBinding.default

uri = URI.parse("http://localhost:8080/event-example/kafka-broker")
data = Messages::Orders::Created.new(
  id: UUID.random,
  customer_name: "Jamie",
)
count = 0
spawn do
  loop do
    start = Time.monotonic
    sleep 1.second

    pp rate: count // (Time.monotonic - start).total_seconds
    count = 0
  end
end

requests = Channel(HTTP::Request).new(10_000)
10_000.times do
  event = CloudEvents::Event::V1.new(
    data: {target: "lol"},
    data_content_type: "application/json",
    id: UUID.random.to_s,
    source: URI.parse("https://omg.lol/"),
    spec_version: "1.0",
    type: "stuff.jgaskins.dev",
  )

  requests.send http_binding.encode_event(uri, event)
end

50.times do
  spawn do
    http = HTTP::Client.new(uri)
    loop do
      http.exec requests.receive
      count += 1
    end
  end
end

gets

require "uuid/json"

module Messages
  struct Orders::Created
    include CloudEvents::EventData

    getter id : UUID
    getter customer_name : String

    def initialize(@id, @customer_name)
    end
  end
end
