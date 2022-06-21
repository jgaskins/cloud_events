#!/usr/bin/env bash

HOST=http://localhost:8080

curl -v "$HOST/event-example/kafka-broker" \
-H "CE-ID: 123" \
-H "CE-Type: hello-world.jgaskins.dev" \
-H "CE-Source: /curl" \
-H "CE-SpecVersion: 1.0" \
-H "Content-Type: application/json" \
-d '{"target":"world"}'


curl -v "$HOST/event-example/kafka-broker" \
-H "CE-ID: daslfkjhasdlfkjh" \
-H "CE-Type: stuff.jgaskins.dev" \
-H "CE-Source: /curl" \
-H "CE-SpecVersion: 1.0" \
-H "Content-Type: application/json" \
-d '{"target":"doing stuff"}'
