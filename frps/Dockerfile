FROM snowdreamtech/frps:0.68.1-alpine3.23

COPY frps.toml /etc/frp/frps.toml

HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=5 \
    CMD ["sh", "-c", "frps verify -c /etc/frp/frps.toml && nc -z 127.0.0.1 7000 && nc -z 127.0.0.1 7500 && nc -z 127.0.0.1 8080 && nc -z 127.0.0.1 8443 && nc -z 127.0.0.1 8081"]
