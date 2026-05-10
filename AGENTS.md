# Repository Guidelines

## 项目结构与模块组织

这是一个基于 Docker 的本地代理栈。

- `docker-compose.yml` 是顶层入口，负责包含所有服务的 compose 文件。
- `caddy/` 存放反向代理镜像、`Caddyfile`、启动脚本、snippet 和可复用模板。
- `dnsmasq/` 存放本地 DNS 服务及其 resolver 说明。
- `dozzle/`、`3xui/`、`socket-proxy/` 各自定义一个服务。
- `makefile` 封装常用生命周期命令。

服务专属配置应放在各自目录中。共享的代理逻辑应放在 `caddy/templates/` 或 `caddy/snippets/`。

## 构建、测试与开发命令

- `make up` 以后台模式启动整套服务。
- `make down` 停止并移除整套服务。
- `make restart` 重启所有服务。
- `make logs` 持续输出 compose 日志。
- `make trust-caddy-cert` 在 macOS 上安装本地 Caddy 根证书。
- `docker-compose up -d caddy` 在代理配置变更时，仅重建并启动 Caddy。

## 编码风格与命名规范

- 保持现有 YAML 缩进风格，与周围文件一致。
- compose 文件和容器名尽量短且按服务命名，例如 `caddy`、`dozzle`、`dns`。
- Shell 脚本尽量保持 POSIX 兼容。`caddy/startup.sh` 使用 `sh` 和 `set -e`。
- 只在意图不明显时添加简短注释，重点放在代理、DNS 和证书行为上。

## 测试指南

这个仓库没有单元测试框架。请通过启动服务并检查运行时行为来验证变更：

- `docker-compose logs -f caddy` 确认 Caddy 启动正常。
- `curl -kI https://dozzle.test.local/` 验证反向代理路由。
- `dig @127.0.0.1 -p 5354 api.test` 验证本地 DNS 解析。

涉及 Caddy 的修改，务必确认启动时配置仍可通过校验。

## 提交与 Pull Request 规范

当前 Git 历史风格简短且偏修复。提交信息保持简短、祈使式，例如：`fix`、`fix proxy`、`update dns`。

Pull Request 应包含：

- 变更内容及原因的简要说明，
- 任何配置或环境变量变更，
- 运行时修复对应的验证步骤和实际结果。

## 安全与配置提示

- 不要提交 `.env` 中的密钥或敏感信息。
- 在 macOS 上，`.local` 是可选项，因为它可能与 Bonjour 冲突。
- 当 Caddy 代理 Docker 内部服务时，要确保代理相关环境变量不会把上游流量送到宿主机代理。
