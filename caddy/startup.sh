#!/bin/sh
set -e

# 设置 ANSI 颜色 (显式定义，便于阅读)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "${BLUE}[INFO] 正在初始化 Caddy 环境...${NC}"

# 1. 环境自检
echo "[INFO] 配置文件: /etc/caddy/Caddyfile"
echo "[INFO] 当前用户: $(whoami)"

# 2. 验证配置文件语法
# 在启动前进行验证，确保不会因为语法错误导致容器启动后立即崩溃
if caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile > /dev/null 2>&1; then
    echo "${GREEN}[SUCCESS] 配置文件语法验证通过${NC}"
else
    echo "${RED}[ERROR] 配置文件语法错误，详细信息如下：${NC}"
    caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
    exit 1
fi

# 3. 启动服务
# 使用 exec 替换当前进程，确保信号能正确传递给 Caddy
echo "${BLUE}[INFO] 正在启动 Caddy 服务...${NC}"
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
