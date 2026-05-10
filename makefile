include .env
export

# 路径定义
CADDY_ROOT_CERT = ./data/caddy/pki/authorities/local/root.crt

.PHONY: validate-docker-compose validate-caddy test-caddy-proxy trust-caddy-cert

validate-docker-compose:
	docker-compose config >/dev/null

validate-caddy:
	docker-compose run --rm --no-deps caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

test-caddy-proxy:
	./test_caddy_proxy.sh

trust-caddy-cert:
	@if [ -f "$(CADDY_ROOT_CERT)" ]; then \
		echo "正在安装 Caddy 根证书到 macOS 系统钥匙串..."; \
		sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$(CADDY_ROOT_CERT)"; \
		echo "证书安装成功！"; \
	else \
		echo "错误: 找不到证书文件 $(CADDY_ROOT_CERT)"; \
		echo "请确保 Caddy 服务已经启动并生成了证书。"; \
	fi
