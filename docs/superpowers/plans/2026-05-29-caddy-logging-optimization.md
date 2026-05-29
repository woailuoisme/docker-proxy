# Caddy 日志系统优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 优化 Caddy 日志配置以消除重复的 HTTP 访问日志打印，增强请求的 Referer 字段记录，并在 Caddy 中全面配置信任 Cloudflare 网段从而正确获取真实的客户端 IP。

**Architecture:** 
1. 全局配置 `log default` 加上 `exclude http.log.access`。
2. 提取 Cloudflare IP 段作为 `trusted_proxies static` 写入 `snippets/trusted-proxies.conf`。
3. 全局块 `import snippets/trusted-proxies.conf`。
4. 站点访问日志 `request-log.conf` 增加 Referer 字段。

**Tech Stack:** Caddy, Docker

---

### Task 1: 建立可信代理配置文件

**Files:**
- Create: `caddy/snippets/trusted-proxies.conf`

- [ ] **Step 1: 创建 `caddy/snippets/trusted-proxies.conf` 并写入 Cloudflare 和内网 IP 地址段**

写入内容：
```caddy
# 信任 Cloudflare IP 地址列表（更新于 2026 年）及 Docker 内网私有网段
servers {
	trusted_proxies static private_ranges 173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22 141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20 197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13 104.24.0.0/14 172.64.0.0/13 131.0.72.0/22 2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32 2405:8100::/32 2a06:98c0::/29 2c0f:f248::/32
}
```

- [ ] **Step 2: 暂存创建的文件**

Run: `git add caddy/snippets/trusted-proxies.conf`

---

### Task 2: 消除全局日志的双重打印

**Files:**
- Modify: `caddy/snippets/global-log.conf`

- [ ] **Step 1: 修改 `caddy/snippets/global-log.conf`**

将原文件修改为：
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

- [ ] **Step 2: 暂存修改**

Run: `git add caddy/snippets/global-log.conf`

---

### Task 3: 在主配置中载入可信代理设置

**Files:**
- Modify: `caddy/Caddyfile`

- [ ] **Step 1: 修改全局配置引入代理网段**

在 `caddy/Caddyfile` 全局 `{ ... }` 块的顶部添加：
```caddy
	import snippets/trusted-proxies.conf
```
修改后的全局块类似于：
```caddy
{
	import snippets/global-log.conf
	import snippets/trusted-proxies.conf
	acme_dns cloudflare {env.CF_API_TOKEN}
}
```

- [ ] **Step 2: 暂存修改**

Run: `git add caddy/Caddyfile`

---

### Task 4: 站点日志增加 Referer 字段

**Files:**
- Modify: `caddy/snippets/request-log.conf`

- [ ] **Step 1: 修改 transform 日志格式**

修改 `caddy/snippets/request-log.conf` 中的格式字符串，在 User-Agent 前插入 Referer 头部：
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

- [ ] **Step 2: 暂存修改**

Run: `git add caddy/snippets/request-log.conf`

---

### Task 5: 校验配置并重新载入服务

- [ ] **Step 1: 执行配置校验**

在 `/Users/seaside/Projects/docker/proxy` 路径下执行配置校验：
Run: `docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile`
Expected: [SUCCESS] 配置文件语法验证通过。

- [ ] **Step 2: 重新加载 Caddy 服务**

运行 Caddy 的 reload 指令，以无缝方式应用配置变更：
Run: `docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile`
Expected: 重新载入成功。

- [ ] **Step 3: 提交更改**

Run: `git commit -m "feat: optimize caddy log output and support cloudflare trusted proxies"`
