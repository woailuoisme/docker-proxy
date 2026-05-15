#!/bin/sh
set -e

echo "[INFO] 正在初始化 Caddy 环境..."

# 1. 环境自检
echo "[INFO] 配置文件: /etc/caddy/Caddyfile"
echo "[INFO] 当前用户: $(whoami)"

# 2. 验证配置文件语法
# 在启动前进行验证，确保不会因为语法错误导致容器启动后立即崩溃
if caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile > /dev/null 2>&1; then
    echo "[SUCCESS] 配置文件语法验证通过"
else
    echo "[ERROR] 配置文件语法错误，详细信息如下："
    caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
    exit 1
fi

# 3. 启动服务
# 使用 exec 替换当前进程，确保信号能正确传递给 Caddy
echo "[INFO] 正在启动 Caddy 服务..."
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
