set dotenv-load := true

# 路径定义
caddy_root_cert := "./data/caddy/pki/authorities/local/root.crt"

# 运行所有检测（只读，不修改文件）
lint: lint-shell lint-dockerfile lint-caddy validate-docker-compose

# 自动修复所有能修复的问题，完成后运行 lint 确认
fix: fix-shell lint

# shfmt 原地修复 shell 脚本格式
fix-shell:
    find . -name "*.sh" -not -path "*/.*" -not -path "./data/*" | xargs shfmt -w

# shellcheck 检测所有 shell 脚本
lint-shell:
    find . -name "*.sh" -not -path "*/.*" -not -path "./data/*" | xargs shellcheck

# hadolint 检测所有 Dockerfile
lint-dockerfile:
    find . -name "Dockerfile*" -not -path "*/.*" -not -path "./data/*" | xargs hadolint

# 验证 docker-compose 配置
validate-docker-compose:
    docker-compose config >/dev/null

# 验证 Caddy 配置文件
lint-caddy:
    #!/usr/bin/env sh
    if ! docker info >/dev/null 2>&1; then
        echo "Docker is not running, skipping Caddy config validation"
        exit 0
    fi
    docker-compose run --rm --no-deps caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

# 测试 Caddy 代理
test-caddy-proxy:
    ./scripts/test_caddy_proxy.sh

# 测试 Caddy WAF 规则
test-waf *args:
    ./scripts/test_waf.sh {{args}}

# 安装 Caddy 根证书到 macOS 系统钥匙串
trust-caddy-cert:
    #!/usr/bin/env bash
    if [ -f "{{ caddy_root_cert }}" ]; then
        echo "Installing Caddy root certificate to macOS system keychain..."
        sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "{{ caddy_root_cert }}"
        echo "Certificate installed successfully."
    else
        echo "Error: certificate file not found: {{ caddy_root_cert }}"
        echo "Make sure Caddy has started and generated the certificate."
    fi
