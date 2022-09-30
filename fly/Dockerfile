FROM alpine:latest

RUN apk add nginx

COPY nginx.conf /etc/nginx/

ENTRYPOINT ["/usr/sbin/nginx"]