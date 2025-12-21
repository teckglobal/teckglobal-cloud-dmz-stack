FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    docker-cli \
    openssh-client \
    coreutils

COPY docker-dns-sync.sh /usr/local/bin/docker-dns-sync
RUN chmod +x /usr/local/bin/docker-dns-sync

ENTRYPOINT ["/usr/local/bin/docker-dns-sync"]
CMD ["watch"]
