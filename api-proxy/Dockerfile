FROM alpine:latest as builder

RUN apk add go

WORKDIR /build
COPY . /build/

RUN go build .

FROM alpine:latest

COPY --from=builder /build/api-proxy /bin/api-proxy

ENTRYPOINT [ "/bin/api-proxy" ]