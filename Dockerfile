FROM alpine:3.23.4

RUN apk add --no-cache rsync nfs-utils

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 873

ENTRYPOINT ["/entrypoint.sh"]