# 本地编译版 OpenClaw 常用指令

## 适用范围

这份手册面向当前这份本地源码仓库的个人使用场景，重点不是“所有官方命令”，而是“日常最常用、最稳、最容易形成固定动作”的那一批命令。

默认约定：

- 在仓库根目录执行命令。
- 源码版优先使用 `pnpm openclaw ...`，避免误用全局安装的 `openclaw`。
- Gateway 运行时优先使用 Node，不用 Bun 跑 WhatsApp Gateway。
- 当前仓库内的 `scripts/gw-*.sh` 是本地定制脚本，适合这台机器的日常使用。

## 管理原则

把这套本地版 OpenClaw 当成一个长期运行的小型基础设施，而不是一次性脚本：

1. 任何更新都走固定流程：更新 -> 编译 -> doctor -> 重启 -> 健康检查。
2. 任何渠道问题都先分层排查：Gateway 是否活着 -> 渠道是否连上 -> 权限和 allowlist 是否正确 -> 凭据是否损坏。
3. 任何配置修改都先备份 `~/.openclaw/openclaw.json`，再改，再重启验证。
4. WhatsApp 问题优先处理“登录态”和“访问控制”，不要一上来就怀疑模型或业务逻辑。
5. 脚本能固化的动作尽量固化，减少每次临场拼命令的成本。

## 一屏速查

| 场景                      | 推荐命令                                                                                              |
| ------------------------- | ----------------------------------------------------------------------------------------------------- |
| 查看仓库状态              | `git status --short --branch`                                                                         |
| 查看更新状态              | `pnpm openclaw update status`                                                                         |
| 安全更新源码版            | `pnpm openclaw update`                                                                                |
| 手工编译                  | `pnpm install && pnpm build && pnpm ui:build`                                                         |
| 启动本地常驻 Gateway      | `bash scripts/gw-start.sh`                                                                            |
| 查看本地常驻 Gateway 状态 | `bash scripts/gw-status.sh`                                                                           |
| 重启本地常驻 Gateway      | `bash scripts/gw-restart.sh`                                                                          |
| 查看总体状态              | `pnpm openclaw status --deep`                                                                         |
| 查看健康检查              | `pnpm openclaw health --verbose`                                                                      |
| 跟踪日志                  | `pnpm openclaw logs --follow --local-time`                                                            |
| 修复配置和状态            | `pnpm openclaw doctor --repair`                                                                       |
| 查看渠道状态              | `pnpm openclaw channels status --probe`                                                               |
| 登录 WhatsApp             | `pnpm openclaw channels login --channel whatsapp`                                                     |
| 重新登录 WhatsApp         | `pnpm openclaw channels logout --channel whatsapp && pnpm openclaw channels login --channel whatsapp` |
| 查看 WhatsApp 配对申请    | `pnpm openclaw pairing list whatsapp`                                                                 |
| 批准 WhatsApp 配对        | `pnpm openclaw pairing approve whatsapp <CODE>`                                                       |

## 1. 日常运维指令

### 1.1 更新源码版 OpenClaw

更新前先看工作区是否干净：

```bash
git status --short --branch
git remote -v
pnpm openclaw update status
```

推荐更新方式：

```bash
pnpm openclaw update
```

说明：

- 这条命令适合源码安装场景。
- 它会走更新、安装依赖、构建、doctor、重启这一条相对安全的链路。
- 如果工作区不干净，先处理本地改动，再更新。

### 1.2 手工更新和编译

当你想手工控制每一步时，按下面顺序做：

```bash
git status --short --branch
git pull --rebase
pnpm install
pnpm build
pnpm ui:build
pnpm openclaw doctor
```

如果只是重新编译本地代码，不拉最新代码：

```bash
pnpm install
pnpm build
pnpm ui:build
```

如果要在编译后顺手做一轮质量检查：

```bash
pnpm check
pnpm test:fast
```

### 1.3 启动 停止 重启 常驻 Gateway

当前仓库已经内置了本地运维脚本，个人使用优先走这套：

```bash
bash scripts/gw-start.sh
bash scripts/gw-status.sh
bash scripts/gw-restart.sh
bash scripts/gw-stop.sh
```

如需安装或卸载本地 `launchd` 常驻服务：

```bash
bash scripts/gw-ha-install.sh
bash scripts/gw-ha-uninstall.sh
```

这套脚本的特点：

- 使用 macOS `launchd` 常驻运行。
- 默认监听 `18789` 端口。
- 默认日志输出到 `/tmp/openclaw-gateway-src.log` 和 `/tmp/openclaw-gateway-src.err.log`。
- 当前脚本里写死了仓库路径和本地代理地址；如果仓库目录变了，或者本地代理端口变了，要先改脚本再用。

### 1.4 官方 Gateway 命令

如果不想走本地脚本，也可以直接走官方 CLI：

```bash
pnpm openclaw gateway run --allow-unconfigured --port 18789
pnpm openclaw gateway status
pnpm openclaw gateway restart
pnpm openclaw gateway stop
```

当端口被占用又想强制拉起时：

```bash
pnpm openclaw gateway run --allow-unconfigured --force --port 18789
```

## 2. 渠道管理指令

### 2.1 通用渠道管理

先看当前都配了哪些渠道、状态是否健康：

```bash
pnpm openclaw channels list
pnpm openclaw channels status
pnpm openclaw channels status --probe
pnpm openclaw channels capabilities
pnpm openclaw channels logs --channel all
```

对需要 token 的渠道，优先用 `channels add`：

```bash
pnpm openclaw channels add
pnpm openclaw channels add --channel telegram --token <bot-token>
pnpm openclaw channels add --channel discord --token <bot-token>
pnpm openclaw channels remove --channel telegram --delete
```

经验规则：

- WhatsApp 这种需要扫码登录的渠道，用 `channels login`。
- Telegram、Discord 这种 token 型渠道，用 `channels add`。
- 增删渠道后，固定补一轮 `channels status --probe`。

### 2.2 WhatsApp 新增 登录和基本配置

先写访问控制，再登录，避免“连上了但谁都能发”或“连上了但自己收不到”。

示例，设成个人常用的 allowlist 模式：

```bash
pnpm openclaw config set channels.whatsapp.dmPolicy '"allowlist"' --strict-json
pnpm openclaw config set channels.whatsapp.allowFrom '["+8613800000000"]' --strict-json
pnpm openclaw config set channels.whatsapp.groupPolicy '"allowlist"' --strict-json
pnpm openclaw config set channels.whatsapp.groupAllowFrom '["+8613800000000"]' --strict-json
pnpm openclaw config set channels.whatsapp.groups '["*"]' --strict-json
```

然后登录：

```bash
pnpm openclaw channels login --channel whatsapp
bash scripts/gw-restart.sh
pnpm openclaw channels status --probe
```

如果你走的是配对模式，还要批准首次配对：

```bash
pnpm openclaw pairing list whatsapp
pnpm openclaw pairing approve whatsapp <CODE>
```

多账号时可以显式指定账号：

```bash
pnpm openclaw channels login --channel whatsapp --account work
pnpm openclaw pairing list --channel whatsapp --account work
```

### 2.3 WhatsApp 代理场景

这个 fork 已经加了 WhatsApp 代理支持。命令行前台运行时，可以先导出代理环境变量：

```bash
export HTTPS_PROXY=http://127.0.0.1:7897
export HTTP_PROXY=http://127.0.0.1:7897
pnpm openclaw channels login --channel whatsapp
```

如果走当前仓库内的 `launchd` 脚本，则脚本本身已经写了代理环境变量。

### 2.4 WhatsApp 修复和重登

最常见的修复顺序：

```bash
pnpm openclaw channels status --probe
pnpm openclaw logs --follow --local-time
pnpm openclaw doctor
```

如果状态显示未登录或需要重新扫码：

```bash
pnpm openclaw channels login --channel whatsapp
pnpm openclaw channels status
```

如果已经连过，但断线重连异常或反复循环：

```bash
pnpm openclaw channels logout --channel whatsapp
pnpm openclaw channels login --channel whatsapp --verbose
bash scripts/gw-restart.sh
pnpm openclaw channels status --probe
```

如果怀疑默认账号凭据目录损坏，可以做彻底重置。注意，这会清掉当前 WhatsApp 登录态，需要重新扫码：

```bash
pnpm openclaw channels logout --channel whatsapp
rm -rf ~/.openclaw/credentials/whatsapp/default
pnpm openclaw channels login --channel whatsapp --verbose
bash scripts/gw-restart.sh
pnpm openclaw channels status --probe
```

如果是“能连上，但不回复消息”：

```bash
pnpm openclaw pairing list whatsapp
pnpm openclaw config get channels.whatsapp.dmPolicy
pnpm openclaw config get channels.whatsapp.allowFrom
pnpm openclaw config get channels.whatsapp.groupPolicy
pnpm openclaw config get channels.whatsapp.groupAllowFrom
pnpm openclaw config get channels.whatsapp.groups
pnpm openclaw logs --follow --local-time
```

## 3. 状态 日志 排障指令

### 3.1 固定排障梯子

出问题时，不要乱跳步骤，按这个顺序查：

```bash
bash scripts/gw-status.sh
pnpm openclaw status --deep
pnpm openclaw health --verbose
pnpm openclaw channels status --probe
pnpm openclaw logs --follow --local-time
pnpm openclaw doctor --deep
```

这套顺序背后的逻辑是：

1. 先确认进程和端口是否活着。
2. 再确认 Gateway 自己是否健康。
3. 再确认具体渠道是否可用。
4. 最后看日志和 doctor，避免在错误层级浪费时间。

### 3.2 常用状态命令

```bash
pnpm openclaw status
pnpm openclaw status --all
pnpm openclaw status --deep
pnpm openclaw health
pnpm openclaw health --json
pnpm openclaw health --verbose
```

### 3.3 常用日志命令

```bash
pnpm openclaw logs
pnpm openclaw logs --follow
pnpm openclaw logs --follow --local-time
tail -f /tmp/openclaw-gateway-src.log /tmp/openclaw-gateway-src.err.log
launchctl print gui/$(id -u)/ai.openclaw.gateway-src
```

### 3.4 Doctor 修复

```bash
pnpm openclaw doctor
pnpm openclaw doctor --repair
pnpm openclaw doctor --deep
pnpm openclaw doctor --non-interactive
```

注意：

- `doctor --repair` 会备份配置到 `~/.openclaw/openclaw.json.bak`。
- 当配置结构、状态目录、旧版凭据路径有问题时，先跑 doctor，再决定是否删目录重登。

## 4. 配置 备份 恢复

### 4.1 常用路径

- 配置文件：`~/.openclaw/openclaw.json`
- doctor 备份：`~/.openclaw/openclaw.json.bak`
- 凭据目录：`~/.openclaw/credentials/`
- WhatsApp 默认账号凭据：`~/.openclaw/credentials/whatsapp/default/`
- 工作区：`~/.openclaw/workspace`
- 本地 Gateway 日志：`/tmp/openclaw-gateway-src.log`
- 本地 Gateway 错误日志：`/tmp/openclaw-gateway-src.err.log`

### 4.2 配置读写

```bash
pnpm openclaw config get agents.list
pnpm openclaw config get channels.whatsapp.allowFrom
pnpm openclaw config set gateway.port 18789 --strict-json
pnpm openclaw config unset tools.web.search.apiKey
```

如果是成组修改，通常直接编辑 `~/.openclaw/openclaw.json` 更快；改完固定执行：

```bash
pnpm openclaw doctor
bash scripts/gw-restart.sh
pnpm openclaw channels status --probe
```

### 4.3 备份命令

先备份配置：

```bash
ts="$(date +%F-%H%M%S)"
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json."$ts".bak
```

再做一份状态总备份：

```bash
ts="$(date +%F-%H%M%S)"
tar -czf "$HOME/openclaw-state-$ts.tgz" \
  ~/.openclaw/openclaw.json \
  ~/.openclaw/credentials \
  ~/.openclaw/workspace
```

建议：

- 做大改动前备份一次。
- 做 WhatsApp 凭据清理前备份一次。
- 做上游大版本更新前备份一次。

## 5. 个人固定 SOP

### 5.1 更新 SOP

```bash
git status --short --branch
pnpm openclaw update
bash scripts/gw-restart.sh
pnpm openclaw health --verbose
pnpm openclaw channels status --probe
```

### 5.2 新增 WhatsApp SOP

```bash
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.before-whatsapp.bak
pnpm openclaw config set channels.whatsapp.dmPolicy '"allowlist"' --strict-json
pnpm openclaw config set channels.whatsapp.allowFrom '["+8613800000000"]' --strict-json
pnpm openclaw channels login --channel whatsapp
bash scripts/gw-restart.sh
pnpm openclaw channels status --probe
```

### 5.3 故障恢复 SOP

```bash
bash scripts/gw-status.sh
pnpm openclaw status --deep
pnpm openclaw logs --follow --local-time
pnpm openclaw doctor --repair
pnpm openclaw channels logout --channel whatsapp
pnpm openclaw channels login --channel whatsapp --verbose
bash scripts/gw-restart.sh
pnpm openclaw channels status --probe
```

## 6. 官方参考

- [Updating](/install/updating)
- [channels](/cli/channels)
- [Gateway](/cli/gateway)
- [config](/cli/config)
- [logs](/cli/logs)
- [status](/cli/status)
- [WhatsApp](/channels/whatsapp)
- [Channel troubleshooting](/channels/troubleshooting)
- [Doctor](/gateway/doctor)
- [Health Checks](/gateway/health)
- [WhatsApp 代理接入修改说明](/WHATSAPP_PROXY_PATCH_NOTES_2026-02-21)
