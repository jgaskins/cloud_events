FROM 84codes/crystal:1.4.1-alpine-latest AS builder

COPY . /cloud_events/
WORKDIR /cloud_events/examples/hello_world
RUN shards build --release --static hello_world

FROM scratch
COPY --from=builder /cloud_events/examples/hello_world/bin/hello_world /
CMD ["/hello_world"]
