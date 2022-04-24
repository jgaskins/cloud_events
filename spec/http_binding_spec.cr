require "./spec_helper"

require "../src/http_binding"
require "json"
require "http"

private def assert(expression : Bool)
  expression.should eq true
end

private def refute(expression : Bool)
  expression.should eq false
end

private def assert_equal(expected, actual)
  actual.should eq expected
end

private def assert_raises(exception)
  expect_raises(exception) { yield }
end

private macro assert_kind_of(type, value)
  {{value}}.should be_a {{type}}
end

describe CloudEvents do
  http_binding = CloudEvents::HTTPBinding.default
  minimal_http_binding = CloudEvents::HTTPBinding.new

  my_simple_data = "12345"
  weird_type = "¡Hola!\n\"100%\" 😀 "
  encoded_weird_type = "%C2%A1Hola%21%0A%22100%25%22%20%F0%9F%98%80%20"

  describe "percent_encode" do
    it "percent-encodes an ascii string" do
      str = http_binding.percent_encode my_simple_data
      str.should eq my_simple_data
    end

    it "percent-encodes a string with special characters" do
      str = http_binding.percent_encode weird_type
      str.should eq encoded_weird_type
    end
  end

  describe "percent_decode" do
    encoded_quoted_type = "Hello%20\"Ruby%20world\"%20\"this\\\"is\\\\a\\1string\"%20okay"
    quoted_type = "Hello Ruby world this\"is\\a1string okay"

    it "percent-decodes an ascii string" do
      str = http_binding.percent_decode my_simple_data
      str.should eq my_simple_data
    end

    it "percent-decodes a string with special characters" do
      str = http_binding.percent_decode encoded_weird_type
      str.should eq weird_type
    end

    it "percent-decodes a string with quoted tokens" do
      str = http_binding.percent_decode encoded_quoted_type
      str.should eq quoted_type
    end
  end

  describe "decode" do
    it "decodes JSON" do
      http_json_binding = CloudEvents::HTTPBinding.new
        .register_type("dev.jgaskins.foobar", Dev::JGaskins::FooBar)
        .register_type("dev.jgaskins.yo", Yo)
        .register_decoder("application/json", CloudEvents::Decoder::JSON)

      context = context(
        body: {foo: "bar"}.to_json,
        headers: HTTP::Headers{
          "ce-id"          => "123",
          "ce-source"      => "/asdf",
          "ce-type"        => "dev.jgaskins.foobar",
          "ce-specversion" => "1.0",
          "ce-dataschema"  => "/my_schema",
          "ce-subject"     => "my_subject",
          "ce-time"        => Time.utc.to_rfc3339,
          "content-type"   => "application/json",
        },
      )

      event = http_json_binding.decode_event(context.request)
      foo_bar = event.data.as(Dev::JGaskins::FooBar)


      context = context(
        body: {omg: "lol"}.to_json,
        headers: HTTP::Headers{
          "ce-id"          => "123",
          "ce-source"      => "/asdf",
          "ce-type"        => "dev.jgaskins.yo",
          "ce-specversion" => "1.0",
          "ce-dataschema"  => "/my_schema",
          "ce-subject"     => "my_subject",
          "ce-time"        => Time.utc.to_rfc3339,
          "content-type"   => "application/json",
        },
      )

      event = http_json_binding.decode_event(context.request)
      yo = event.data.as(Yo)

      foo_bar.should be_a Dev::JGaskins::FooBar
      foo_bar.foo.should eq "bar"

      yo.should be_a Yo
      yo.omg.should eq "lol"
    end
  end

  # describe "decode" do
  #   my_content_type_string = "text/plain; charset=us-ascii"
  #   my_content_type = CloudEvents::ContentType.new my_content_type_string
  #   my_id = "my_id"
  #   my_schema_string = "/my_schema"
  #   my_schema = URI.parse my_schema_string
  #   my_source_string = "/my_source"
  #   my_source = URI.parse my_source_string
  #   spec_version = "1.0"
  #   my_subject = "my_subject"
  #   my_time_string = "2020-01-12T20:52:05-08:00"
  #   my_time = Time::Format::RFC_3339.parse my_time_string
  #   my_type = "my_type"

  #   my_json_struct = {
  #     "data"            => my_simple_data,
  #     "datacontenttype" => my_content_type_string,
  #     "dataschema"      => my_schema_string,
  #     "id"              => my_id,
  #     "source"          => my_source_string,
  #     "specversion"     => spec_version,
  #     "subject"         => my_subject,
  #     "time"            => my_time_string,
  #     "type"            => my_type,
  #   }
  #   my_json_struct_encoded = my_json_struct.to_json

  #   my_json_escaped_simple_data = %{"12345"}
  #   my_json_content_type_string = "application/json; charset=us-ascii"
  #   my_json_content_type = CloudEvents::ContentType.new my_json_content_type_string

  #   my_json_data_struct = {
  #     "data"            => my_simple_data,
  #     "datacontenttype" => my_json_content_type_string,
  #     "dataschema"      => my_schema_string,
  #     "id"              => my_id,
  #     "source"          => my_source_string,
  #     "specversion"     => spec_version,
  #     "subject"         => my_subject,
  #     "time"            => my_time_string,
  #     "type"            => my_type,
  #   }
  #   my_json_data_struct_encoded = my_json_data_struct.to_json

  #   my_simple_binary_mode = context(
  #     body: my_simple_data,
  #     headers: HTTP::Headers{
  #       "ce-id"          => my_id,
  #       "ce-source"      => my_source_string,
  #       "ce-type"        => my_type,
  #       "ce-specversion" => spec_version,
  #       "ce-dataschema"  => my_schema_string,
  #       "ce-subject"     => my_subject,
  #       "ce-time"        => my_time_string,
  #       "content-type"   => my_content_type_string,
  #     },
  #   )
  #   my_json_binary_mode = context(
  #     body: my_json_escaped_simple_data,
  #     headers: HTTP::Headers{
  #       "ce-id"          => my_id,
  #       "ce-source"      => my_source_string,
  #       "ce-type"        => my_type,
  #       "ce-specversion" => spec_version,
  #       "ce-dataschema"  => my_schema_string,
  #       "ce-subject"     => my_subject,
  #       "ce-time"        => my_time_string,
  #       "content-type"   => my_json_content_type_string,
  #     },
  #   )

  #   my_json_batch_encoded = [my_json_struct].to_json

  #   my_simple_event = CloudEvents::Event::V1.new(
  #     data_encoded: my_simple_data,
  #     data: my_simple_data,
  #     datacontenttype: my_content_type_string,
  #     dataschema: my_schema_string,
  #     id: my_id,
  #     source: my_source_string,
  #     specversion: spec_version,
  #     subject: my_subject,
  #     time: my_time_string,
  #     type: my_type,
  #   )

  #   my_json_event = CloudEvents::Event::V1.new(
  #     data_encoded: my_json_escaped_simple_data,
  #     data: my_simple_data,
  #     datacontenttype: my_json_content_type_string,
  #     dataschema: my_schema_string,
  #     id: my_id,
  #     source: my_source_string,
  #     specversion: spec_version,
  #     subject: my_subject,
  #     time: my_time_string,
  #     type: my_type,
  #   )

  #   it "decodes a json-structured rack env with text content type" do
  #     event = http_binding.decode_event context(
  #       body: my_json_struct_encoded,
  #       headers: HTTP::Headers{"content-type" => "application/cloudevents+json"},
  #     )
  #     event.should eq my_simple_event
  #   end

  #   it "decodes a json-structured rack env with json content type" do
  #     event = http_binding.decode_event context(
  #       body: my_json_data_struct_encoded,
  #       headers: HTTP::Headers{"content-type" => "application/cloudevents+json"},
  #     )
  #     event.should eq my_json_event
  #   end

  #   it "decodes a json-batch rack env with text content type" do
  #     events = http_binding.decode_event context(
  #       body: my_json_batch_encoded,
  #       headers: HTTP::Headers{"content-type" => "application/cloudevents+json"},
  #     )
  #     events.should eq [my_simple_event]
  #   end

  #   it "decodes a binary mode rack env with text content type" do
  #     event = http_binding.decode_event my_simple_binary_mode
  #     event.should eq my_simple_event
  #   end

  #   it "decodes a binary mode rack env with json content type" do
  #     event = http_binding.decode_event my_json_binary_mode
  #     assert_equal my_json_event, event
  #   end

  #   it "decodes a binary mode rack env omitting optional headers" do
  #     my_minimal_binary_mode = context(
  #       body: "",
  #       headers: HTTP::Headers{
  #         "ce-id"          => my_id,
  #         "ce-source"      => my_source_string,
  #         "ce-type"        => my_type,
  #         "ce-specversion" => spec_version,
  #       },
  #     )
  #     my_minimal_event = CloudEvents::Event::V1.new(
  #       data_encoded: "",
  #       data: "",
  #       id: my_id,
  #       source: my_source_string,
  #       specversion: spec_version,
  #       type: my_type,
  #     )

  #     event = http_binding.decode_event my_minimal_binary_mode
  #     assert_equal my_minimal_event, event
  #   end

  #   it "decodes a binary mode rack env with extension headers" do
  #     my_trace_context = "1234567890;9876543210"

  #     my_extensions_binary_mode = context(
  #       body: my_simple_data,
  #       headers: HTTP::Headers{
  #         "ce-id"           => my_id,
  #         "ce-source"       => my_source_string,
  #         "ce-type"         => my_type,
  #         "ce-specversion"  => spec_version,
  #         "ce-dataschema"   => my_schema_string,
  #         "ce-subject"      => my_subject,
  #         "ce-time"         => my_time_string,
  #         "ce-tracecontext" => my_trace_context,
  #         "content-type"    => my_content_type_string,
  #       },
  #     )
  #     event = http_binding.decode_event my_extensions_binary_mode
  #     event.should eq CloudEvents::Event::V1.new(
  #       data_encoded: my_simple_data,
  #       data: my_simple_data,
  #       datacontenttype: my_content_type_string,
  #       dataschema: my_schema_string,
  #       id: my_id,
  #       source: my_source_string,
  #       specversion: spec_version,
  #       subject: my_subject,
  #       time: my_time_string,
  #       tracecontext: my_trace_context,
  #       type: my_type,
  #     )
  #   end

  #   it "decodes a binary mode rack env with non-ascii characters in a header" do
  #     my_nonascii_binary_mode = context(
  #       body: my_simple_data,
  #       headers: HTTP::Headers{
  #         "ce-id"          => my_id,
  #         "ce-source"      => my_source_string,
  #         "ce-type"        => encoded_weird_type,
  #         "ce-specversion" => spec_version,
  #         "ce-dataschema"  => my_schema_string,
  #         "ce-subject"     => my_subject,
  #         "ce-time"        => my_time_string,
  #         "content-type"   => my_content_type_string,
  #       },
  #     )
  #     event = http_binding.decode_event my_nonascii_binary_mode
  #     event.should eq CloudEvents::Event::V1.new(
  #       data_encoded: my_simple_data,
  #       data: my_simple_data,
  #       datacontenttype: my_content_type_string,
  #       dataschema: my_schema_string,
  #       id: my_id,
  #       source: my_source_string,
  #       specversion: spec_version,
  #       subject: my_subject,
  #       time: my_time_string,
  #       type: weird_type,
  #     )
  #   end

  #   it "decodes a structured event using opaque" do
  #     context = context(
  #       body: my_json_struct_encoded,
  #       headers: HTTP::Headers{
  #         "content-type" => "application/cloudevents+json",
  #       },
  #     )

  #     event = minimal_http_binding.decode_event context, allow_opaque: true
  #     assert_kind_of CloudEvents::Event::Opaque, event
  #     refute event.batch?
  #     assert_equal my_json_struct_encoded, event.content
  #     assert_equal CloudEvents::ContentType.new("application/cloudevents+json"), event.content_type
  #   end

  #   it "decodes a structured batch using opaque", focus: true do
  #     context = context(
  #       body: my_json_batch_encoded,
  #       headers: HTTP::Headers{
  #         "content-type" => "application/cloudevents-batch+json",
  #       },
  #     )

  #     event = minimal_http_binding.decode_event context, allow_opaque: true

  #     assert_kind_of CloudEvents::Event::Opaque, event
  #     assert event.batch?
  #     assert_equal my_json_batch_encoded, event.content
  #     assert_equal CloudEvents::ContentType.new("application/cloudevents-batch+json"), event.content_type
  #   end

  #   it "raises UnsupportedFormatError when a format is not recognized" do
  #     context = context(
  #       body: my_json_struct_encoded,
  #       headers: HTTP::Headers{
  #         "content-type" => "application/cloudevents+hello",
  #       },
  #     )
  #     expect_raises CloudEvents::UnsupportedFormatError do
  #       http_binding.decode_event context
  #     end
  #   end

  #   it "raises FormatSyntaxError when decoding malformed JSON event" do
  #     context = context(
  #       body: "!!!",
  #       headers: HTTP::Headers{
  #         "content-type" => "application/cloudevents+json",
  #       },
  #     )
  #     error = expect_raises CloudEvents::FormatSyntaxError do
  #       http_binding.decode_event context
  #     end
  #     assert_kind_of JSON::ParseException, error.cause
  #   end

  #   it "raises FormatSyntaxError when decoding malformed JSON batch" do
  #     context = context(
  #       body: "!!!",
  #       headers: HTTP::Headers{
  #         "content-type" => "application/cloudevents-batch+json",
  #       },
  #     )
  #     error = assert_raises CloudEvents::FormatSyntaxError do
  #       http_binding.decode_event context
  #     end
  #     assert_kind_of JSON::ParseException, error.cause
  #   end

  #   it "raises SpecVersionError when decoding a binary event with a bad specversion" do
  #     context = context(
  #       headers: HTTP::Headers{
  #         "ce-id"          => my_id,
  #         "ce-source"      => my_source_string,
  #         "ce-type"        => my_type,
  #         "ce-specversion" => "0.1",
  #       },
  #     )
  #     assert_raises CloudEvents::SpecVersionError do
  #       http_binding.decode_event context
  #     end
  #   end

  #   it "raises NotCloudEventError when a content-type is not recognized" do
  #     context = context(
  #       body: my_json_struct_encoded,
  #       headers: HTTP::Headers{
  #         "content_type" => "application/json",
  #       },
  #     )
  #     assert_raises CloudEvents::NotCloudEventError do
  #       http_binding.decode_event context
  #     end
  #   end

  #   it "raises NotCloudEventError when the method is GET" do
  #     context = context(
  #       method: "GET",
  #       body: my_json_struct_encoded,
  #       headers: HTTP::Headers{
  #         "content-type" => "application/cloudevents+json",
  #       },
  #     )
  #     assert_raises CloudEvents::NotCloudEventError do
  #       http_binding.decode_event context
  #     end
  #   end

  #   it "raises NotCloudEventError when the method is HEAD" do
  #     context = context(
  #       method: "HEAD",
  #       body: my_json_struct_encoded,
  #       headers: HTTP::Headers{
  #         "content-type" => "application/cloudevents+json",
  #       },
  #     )
  #     assert_raises CloudEvents::NotCloudEventError do
  #       http_binding.decode_event context
  #     end
  #   end
  # end
end

private def context(*, method = "POST", resource = "/", body : String = "", headers = HTTP::Headers.new)
  context method: method, body: IO::Memory.new(body), headers: headers, resource: resource
end

private def context(*, method = "POST", resource = "/", body : IO, headers = HTTP::Headers.new)
  request = HTTP::Request.new(
    method: method,
    resource: resource,
    body: body,
    headers: headers,
  )
  response = HTTP::Server::Response.new(IO::Memory.new)
  HTTP::Server::Context.new(request, response)
end

struct Dev::JGaskins::FooBar
  include JSON::Serializable
  include CloudEvents::EventData

  getter foo : String
end

struct Yo
  include JSON::Serializable
  include CloudEvents::EventData

  getter omg : String
end
