#!/bin/sh
set -e

# 日志格式化输出函数，形式为：YYYY-MM-DD HH:MM:SS [LEVEL] - MESSAGE
log() {
	dt=$(date '+%Y-%m-%d %H:%M:%S')
	echo "${dt} [$1] - $2"
}

log "INFO" "正在初始化 Caddy 环境..."

# 1. 环境自检
log "INFO" "配置文件: /etc/caddy/Caddyfile"
current_user=$(whoami)
log "INFO" "当前用户: ${current_user}"

# 2. 验证配置文件语法
# 在启动前进行验证，确保不会因为语法错误导致容器启动后立即崩溃
if caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1; then
	log "SUCCESS" "配置文件语法验证通过"
else
	log "ERROR" "配置文件语法错误，详细信息如下："
	caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
	exit 1
fi

# 3. 启动服务
# 使用 exec 替换当前进程，确保信号能正确传递给 Caddy
log "INFO" "正在启动 Caddy 服务..."
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
