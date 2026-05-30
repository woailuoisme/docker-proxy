FROM jiaoio/caddy-base:2.11.3

COPY snippets /etc/caddy/snippets
COPY templates /etc/caddy/templates
COPY startup.sh /usr/local/bin/startup.sh
COPY Caddyfile /etc/caddy/Caddyfile
RUN chmod +x /usr/local/bin/startup.sh

CMD ["/usr/local/bin/startup.sh"]

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider -Y off http://127.0.0.1/health || exit 1
