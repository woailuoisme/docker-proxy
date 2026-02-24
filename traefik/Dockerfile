ARG VERSION=v3.6
FROM traefik:${VERSION}

WORKDIR /etc/traefik

ENV TZ=Asia/Shanghai

RUN mkdir -p /config/acme /config/dynamic /traefik/logs \
    && chmod -R 600 /config/acme

COPY traefik.yml .
COPY dynamic /config/dynamic

HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --no-check-certificate --spider http://localhost:80/ping || exit 1

EXPOSE 80 443

ENTRYPOINT ["traefik"]
CMD ["--configfile=/etc/traefik/traefik.yml"]
