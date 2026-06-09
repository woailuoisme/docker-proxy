set dotenv-load := true

# 路径定义
caddy_root_cert := "./data/caddy/pki/authorities/local/root.crt"

# 运行所有检测（只读，不修改文件）
lint: lint-shell lint-dockerfile lint-caddy validate-docker-compose lint-dotenv

# 自动修复所有能修复的问题，完成后运行 lint 确认
fix: fix-shell lint

# shfmt 原地修复 shell 脚本格式
fix-shell:
    fd -e sh --no-ignore-vcs | xargs shfmt -w

# dotenv-linter 检测所有 .env 文件（跳过 key 排序规则，保留手动分组）
lint-dotenv:
    fd -g '.env*' --no-ignore --hidden | xargs dotenv-linter check -i UnorderedKey

# shellcheck 检测所有 shell 脚本
lint-shell:
    fd -e sh | xargs shellcheck

# hadolint 检测所有 Dockerfile
lint-dockerfile:
    fd -g 'Dockerfile*' | xargs hadolint

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

# 查看 RustDesk 服务端公钥（客户端 Key 字段填此值）
rustdesk-key:
    #!/usr/bin/env sh
    key="{{justfile_directory()}}/data/rustdesk/id_ed25519.pub"
    if [ -f "$key" ]; then
        cat "$key"
    else
        echo "Error: key file not found: $key"
        echo "Make sure RustDesk has started and finished initialization."
        exit 1
    fi

# 测试 Caddy 代理
test-caddy-proxy:
    ./test_caddy_proxy.sh

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
