include .env
export

# 路径定义
CADDY_ROOT_CERT = ./data/caddy/pki/authorities/local/root.crt

.PHONY: help up down restart logs trust-caddy-cert

help:
	@echo "可用命令:"
	@echo "  make up                 - 启动所有服务"
	@echo "  make down               - 停止并移除所有服务"
	@echo "  make restart            - 重启所有服务"
	@echo "  make logs               - 查看所有服务日志"
	@echo "  make trust-caddy-cert   - 将 Caddy 根证书添加到 macOS 受信任列表"

up:
	docker-compose up -d

down:
	docker-compose down

restart:
	docker-compose restart

logs:
	docker-compose logs -f

trust-caddy-cert:
	@if [ -f "$(CADDY_ROOT_CERT)" ]; then \
		echo "正在安装 Caddy 根证书到 macOS 系统钥匙串..."; \
		sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$(CADDY_ROOT_CERT)"; \
		echo "证书安装成功！"; \
	else \
		echo "错误: 找不到证书文件 $(CADDY_ROOT_CERT)"; \
		echo "请确保 Caddy 服务已经启动并生成了证书。"; \
	fi
