require "http"
require "cloud_events/http_binding"

require "interro"
require "db"
Interro.config { |c| c.db = DB.open(ENV["DATABASE_URL"]) }

events = CloudEvents::HTTPBinding.default
  .register_type("hello-world.jgaskins.dev", HelloWorld)
  .register_type("stuff.jgaskins.dev", Stuff)
  .register_type("orders.created", Events::Orders::Created)

in_flight = Atomic.new(0)
http = HTTP::Server.new([HTTP::LogHandler.new]) do |context|
  in_flight.add 1
  if event = events.decode_event(context)
    handle event.data
  else
    context.response.status = :not_found
  end
ensure
  in_flight.sub 1
end

Signal::TERM.trap { http.close }

puts "Listening..."
http.listen "0.0.0.0", 8080

while in_flight.get > 0
  sleep 100.milliseconds
end

# #### Event handlers #####

def handle(data : HelloWorld)
  pp hello_world: data
end

def handle(data : Stuff)
  pp stuff: data.target
end

def handle(data : Events::Orders::Created)
  pp OrderQuery.new.create(data)
end

# #### Event definitions #####

struct HelloWorld
  include CloudEvents::EventData

  getter target : String = ENV.fetch("DEFAULT_TARGET", "World")
end

struct Stuff
  include CloudEvents::EventData

  getter target : String = ENV.fetch("DEFAULT_TARGET", "Knative")
end

require "uuid/json"

module Events
  struct Orders::Created
    include CloudEvents::EventData

    getter id : UUID
    getter customer_name : String
  end
end

# #### Database things #####

struct Order
  include DB::Serializable

  getter id : UUID
  getter customer_name : String
end

struct OrderQuery < Interro::QueryBuilder(Order)
  table "orders"

  def create(msg : Events::Orders::Created)
    insert id: msg.id, customer_name: msg.customer_name
  end
end

PROCESSED_EVENTS = Hash({URI, String}, Time).new

def already_processed?(data) : Bool
  PROCESSED_EVENTS.has_key?({data.source, data.id})
end

def processed!(data) : Nil
  now = Time.utc
  PROCESSED_EVENTS[{data.source, data.id}] = now
  loop do
    key, value = PROCESSED_EVENTS.first
    if PROCESSED_EVENTS.size > 1_000 || value < now - 1.hour
      PROCESSED_EVENTS.delete key
    else
      return
    end
  end
end
