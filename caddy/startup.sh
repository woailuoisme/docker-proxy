#!/bin/sh
set -e

# Caddy 启动脚本：格式化配置、验证并启动
# ---------------------------------------------------------

# 颜色定义
C_RESET="\033[0m"
C_RED="\033[0;31m"
C_GREEN="\033[0;32m"
C_YELLOW="\033[0;33m"
C_BLUE="\033[0;34m"
C_CYAN="\033[0;36m"
C_BOLD="\033[1m"

# 通用日志函数
log() {
  local level="$1"
  local color="$2"
  local msg="$3"
  printf "${C_CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${C_RESET} ${color}[${level}]${C_RESET} ${msg}\n"
}

info() { log "INFO" "${C_BLUE}" "$1"; }
success() { log "SUCCESS" "${C_GREEN}" "$1"; }
warn() { log "WARN" "${C_YELLOW}" "$1"; }
error() { log "ERROR" "${C_RED}" "$1"; }

# 格式化 Caddy 配置文件
format_configs() {
  info "开始格式化 Caddy 配置文件..."
  
  # 搜集所有配置文件
  local files="/etc/caddy/Caddyfile $(find /etc/caddy/snippets /etc/caddy/templates -name "*.conf" 2>/dev/null || true)"
  local ok=0 skip=0

  for f in $files; do
    [ ! -f "$f" ] && continue
    
    if caddy fmt --overwrite "$f" >/dev/null 2>&1; then
      success "已格式化: $f"
      ok=$((ok + 1))
    else
      skip=$((skip + 1))
    fi
  done
  
  success "格式化完成 (成功: $ok, 跳过: $skip)"
}

# 验证并显示环境信息
prepare_service() {
  printf "${C_BOLD}${C_CYAN}=== Caddy 环境信息 ===${C_RESET}\n"
  info "配置文件: /etc/caddy/Caddyfile"
  info "工作目录: $(pwd)"
  info "用户身份: $(whoami)"
  
  format_configs

  info "验证配置合法性..."
  if ! caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1; then
    error "配置验证失败，请检查 Caddyfile"
    exit 1
  fi
  success "配置验证通过"

  printf "${C_BOLD}${C_CYAN}=== Caddy 模块预览 ===${C_RESET}\n"
  caddy list-modules | grep -E "modules" || true
  printf "${C_BOLD}${C_CYAN}========================${C_RESET}\n\n"
}

# 主入口
main() {
  prepare_service
  
  success "服务启动准备就绪"
  printf "${C_BOLD}${C_GREEN}执行: caddy run --config /etc/caddy/Caddyfile --adapter caddyfile${C_RESET}\n\n"

  exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
}

# 信号处理
trap 'warn "接收到停止信号，正在退出..."; exit 0' SIGTERM SIGINT

main "$@"
