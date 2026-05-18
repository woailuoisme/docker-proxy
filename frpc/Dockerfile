FROM snowdreamtech/frpc:0.68.1-alpine3.23

COPY frpc.toml /etc/frp/frpc.toml

HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=5 \
    CMD ["sh", "-c", "frpc verify -c /etc/frp/frpc.toml && frpc status -c /etc/frp/frpc.toml >/dev/null 2>&1"]
