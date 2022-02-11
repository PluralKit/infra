FROM alpine:latest AS builder

RUN apk add go
WORKDIR /build
COPY . .
RUN go build -o backup .

FROM alpine:latest

RUN apk add postgresql14-client borgbackup openssh-client

COPY --from=builder /build/backup /backup

CMD ["/backup"]