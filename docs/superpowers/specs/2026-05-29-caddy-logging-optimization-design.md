# Caddy 日志优化设计文档

本文档定义了对 Docker Proxy 项目中 Caddy 服务日志系统进行的全面优化方案。该优化旨在解决当前日志系统的双重输出问题、无法获取真实客户端访客 IP 的缺陷，并增强日志的信息维度以便于问题排查。

## 1. 现状与痛点

1. **日志双重打印（Duplicate Logging）**：
   - 现有的全局日志配置（`global-log.conf`）默认会捕获包括 HTTP 访问在内的所有系统及访问事件。
   - 站点访问日志配置（`request-log.conf`）又会将每个站点的 HTTP 访问事件独立输出到 `stdout`。
   - 二者均输出至 `stdout`，这导致每次 HTTP 请求都会在 `docker logs caddy` 中输出两遍相同的信息，增加日志冗余并干扰人工调试。

2. **多层代理下的真实 IP 缺失**：
   - Caddy 通过 Cloudflare 提供 DNS 解析，流量经过了 Cloudflare CDN 代理。
   - 当前站点访问日志中 `{request>remote_ip}` 记录的是 Cloudflare 节点的公网 IP，而非用户的真实访问 IP。这在排查攻击、异常流量时缺失了关键审计数据。

3. **请求来源（Referer）缺失**：
   - 目前的 `request-log.conf` 中仅记录了 `User-Agent`，缺失了 `Referer` 字段，增加了分析跨站流量或静态资源防盗链审计的难度。

## 2. 优化方案设计

### 2.1 全局日志去重

修改全局日志配置文件 `snippets/global-log.conf`，通过在日志块中加入 `exclude http.log.access`，彻底将 HTTP 访问日志从全局 `default` 记录器中排除，使之只专注于记录 Caddy 自身的系统/启动/TLS等日志。

### 2.2 信任 Cloudflare 代理

1. 鉴于内置 Caddy 基础镜像目前没有集成 `cloudflare-ips` 动态解析插件，本项目将使用静态定义所有 Cloudflare 官方 IPv4/IPv6 网段的方式。
2. 创建新的 snippets 文件 `snippets/trusted-proxies.conf`，将 Cloudflare 公网 IP 以及 Docker 内部私有 IP 网段（`private_ranges`）定义在 `servers { trusted_proxies static ... }` 块中。
3. 在主 `Caddyfile` 全局配置中 `import` 引入该配置，使 Caddy 能够在信任代理节点后，安全地读取 `X-Forwarded-For` 中的真实 IP，并自动还原到 `{request>remote_ip}` 中。

### 2.3 站点访问日志增强

修改 `snippets/request-log.conf`，在已有的 `{ts}`、`{level}`、`{request>remote_ip}` 等字段之后，在 `User-Agent` 之前增加 `{request>headers>Referer>[0]}`，以实现更完善的请求追踪。

## 3. 具体修改方案

### 3.1 [NEW] `caddy/snippets/trusted-proxies.conf`

```caddy
# 信任 Cloudflare IP 地址列表（更新于 2026 年）及 Docker 内网私有网段
servers {
	trusted_proxies static private_ranges 173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 104.24.0.0/14 172.64.0.0/13 131.0.72.0/22 2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32 2405:8100::/32 2a06:98c0::/29 2c0f:f248::/32
}
```

### 3.2 [MODIFY] `caddy/snippets/global-log.conf`

```caddy
log default {
	output stdout
	level INFO
	# 过滤 HTTP 访问日志，防止重复记录
	exclude http.log.access
	format console {
		time_format "2006-01-02 15:04:05"
		duration_format "string"
		time_local
	}
}
```

### 3.3 [MODIFY] `caddy/Caddyfile`

在全局块的顶部引入代理网段：

```diff
 {
 	import snippets/global-log.conf
+	import snippets/trusted-proxies.conf
 	acme_dns cloudflare {env.CF_API_TOKEN}
```

### 3.4 [MODIFY] `caddy/snippets/request-log.conf`

```caddy
log {
	output stdout
	level INFO
	# 引入请求来源 Referer 到 transform 中
	format transform `{ts} [{level}] "{request>remote_ip} {status} {duration} {request>proto} {request>method} {request>host}{request>uri} {size}" "{request>headers>Referer>[0]}" "{request>headers>User-Agent>[0]}" ` {
		time_format "2006-01-02 15:04:05"
		duration_format "string"
		time_local
		level_format "upper"
	}
}
```

## 4. 验证方案

1. **语法及结构验证**：
   - 运行本地校验命令 `docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile` 确保语法配置无误。
2. **日志打印测试**：
   - 模拟请求任一虚拟主机（如 `dozzle.example.com` 等），确认 `docker logs caddy` 输出中：
     - 系统全局日志中不再出现重复的 HTTP 访问打印。
     - 访问日志输出包含准确的真实的访客 IP（如果通过 Cloudflare 网络请求）。
     - 访问日志输出中成功包含 Referer 首部。
