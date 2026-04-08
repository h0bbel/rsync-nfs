FROM alpine:3.23.3

RUN apk add --no-cache rsync nfs-utils

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 873

ENTRYPOINT ["/entrypoint.sh"]