set dotenv-load := true

# 路径定义
caddy_root_cert := "./data/caddy/pki/authorities/local/root.crt"

# 验证 docker-compose 配置
validate-docker-compose:
    docker-compose config >/dev/null

# 验证 Caddy 配置文件
validate-caddy:
    docker-compose run --rm --no-deps caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

# 测试 Caddy 代理
test-caddy-proxy:
    ./test_caddy_proxy.sh

# 安装 Caddy 根证书到 macOS 系统钥匙串
trust-caddy-cert:
    #!/usr/bin/env bash
    if [ -f "{{ caddy_root_cert }}" ]; then
        echo "正在安装 Caddy 根证书到 macOS 系统钥匙串..."
        sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "{{ caddy_root_cert }}"
        echo "证书安装成功！"
    else
        echo "错误: 找不到证书文件 {{ caddy_root_cert }}"
        echo "请确保 Caddy 服务已经启动并生成了证书。"
    fi
