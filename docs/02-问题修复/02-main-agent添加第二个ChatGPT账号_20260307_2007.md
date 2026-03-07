# main agent 添加第二个 ChatGPT 账号记录

## 基本信息

- 问题/需求：为 `main` agent 增加第二个 ChatGPT（`openai-codex` OAuth）账号。
- 处理日期：2026-03-07（Asia/Shanghai）
- 记录时间：2026-03-07 20:07（Asia/Shanghai）
- 处理范围：
  - `~/.openclaw/agents/main/agent/auth-profiles.json`
  - `~/.openclaw/openclaw.json`

## 处理目标

- 在 `main` agent 下保留原有 ChatGPT 账号。
- 新增第二个 ChatGPT 账号，形成同一 provider 下的双 profile 配置。
- 明确 `main` 的 profile 顺序，避免默认账号被新账号替换。
- 验证两个账号都能被 `main` agent 正常识别和实际调用。

## 初始状态

处理前，本机 OpenClaw 共有 3 个 agent：

- `main`
- `project-task`
- `mc-gateway-520239c5-b9b5-475e-b460-bc9f59571f95`

其中：

- 默认 agent 是 `main`
- `main` 的 `auth-profiles.json` 中只有 1 个 `openai-codex` profile：
  - `openai-codex:default`
- 该 profile 对应原账号：
  - `lesshst@gmail.com`

## 关键排查与处理过程

### 1. 确认登录写入目标就是 `main`

先确认 `openclaw models auth login` 的行为范围：

- `models auth login` 命令本身没有 `--agent` 参数
- 源码逻辑会把 OAuth 凭据写入“默认 agent”
- 当前配置下默认 agent 正是 `main`

因此，本次新增第二个账号时，不需要切换默认 agent，直接在当前环境登录即可把 OAuth 写入 `main`。

### 2. 发起第二个 ChatGPT 账号的 OAuth 登录

执行：

```bash
openclaw models auth login --provider openai-codex
```

浏览器授权完成后，CLI 返回：

- `OpenAI OAuth complete`
- `Auth profile: openai-codex:default (openai-codex/oauth)`

这一步表面上看登录成功，但有一个关键异常：

- 返回的 profile id 仍然是 `openai-codex:default`
- 没有自动生成第二个独立 profile

### 3. 识别“新增失败，实际发生的是覆盖”

登录完成后检查 `main` 的 `auth-profiles.json`，发现：

- `openai-codex:default` 已被新登录账号覆盖
- 原来的 `lesshst@gmail.com` 不再出现在当前主文件中

进一步检查备份与凭据内容后确认：

- 原账号：`lesshst@gmail.com`
- 新账号：`lizhibo360106773@gmail.com`

实际发生的事情不是“新增第二个账号”，而是：

- 新账号登录成功
- 但 OAuth 写入阶段仍使用 `openai-codex:default`
- 于是把原来的默认账号覆盖掉了

### 4. 从备份恢复原账号，并把新账号转成独立 profile

为避免丢失原账号，先从历史备份中找回原 OAuth 凭据：

- `~/.openclaw/agents/main/agent/auth-profiles.json.autoadd.1772288810.bak`

随后对当前和备份中的 OAuth 令牌做对比，解出各自 email，得到：

- 原账号：`lesshst@gmail.com`
- 新账号：`lizhibo360106773@gmail.com`

然后完成以下整理：

- 将原账号恢复为 `openai-codex:default`
- 将新账号写为独立 profile：
  - `openai-codex:lizhibo360106773@gmail.com`
- 在 `openclaw.json` 的 `auth.profiles` 中同步登记两个 profile 的元数据
- 保持 provider 为 `openai-codex`
- 模式都为 `oauth`

同时，为了防止再次因为手工整理出错，额外创建了本次操作前的备份：

- `~/.openclaw/agents/main/agent/auth-profiles.json.codex-pre-second-account-20260307120325.bak`
- `~/.openclaw/openclaw.json.codex-pre-second-account-20260307120325.bak`

### 5. 为 `main` 写入显式 profile 顺序

为了让原来的默认账号继续排在第一顺位，执行：

```bash
openclaw models auth order set --agent main --provider openai-codex \
  openai-codex:default \
  openai-codex:lizhibo360106773@gmail.com
```

写入后的顺序覆盖为：

- 第一顺位：`openai-codex:default`
- 第二顺位：`openai-codex:lizhibo360106773@gmail.com`

这样即使同一 provider 下存在多个 profile，`main` 也会优先使用原默认账号。

## 最终结果

截至本次处理完成后，`main` agent 下的 `openai-codex` 配置为：

- `openai-codex:default`
  - email: `lesshst@gmail.com`
- `openai-codex:lizhibo360106773@gmail.com`
  - email: `lizhibo360106773@gmail.com`

并且 `main` 的 `auth order` 已显式写为：

```text
openai-codex:default
openai-codex:lizhibo360106773@gmail.com
```

## 验证结果

使用以下命令做 live probe：

```bash
openclaw models status --agent main --probe --probe-provider openai-codex \
  --probe-profile openai-codex:default \
  --probe-profile openai-codex:lizhibo360106773@gmail.com \
  --json
```

返回结果显示：

- `openai-codex (2)` 已被识别
- 两个 profile 都是 `OAuth`
- 两个 profile 的状态都为 `ok`
- probe 结果：
  - `openai-codex:default` -> `status: ok`
  - `openai-codex:lizhibo360106773@gmail.com` -> `status: ok`

说明：

- 双账号结构已写入成功
- 两个账号都不是“静态存在”，而是可以被 `main` 实际调用

## 本次处理的一个重要发现

当前 `openai-codex` 的登录流程存在一个需要注意的行为：

- 发起第二次 OAuth 登录时，CLI 可能仍然写入 `openai-codex:default`
- 结果不是“自动新增第二个 profile”，而是“覆盖原默认 profile”

因此，如果后续还要继续为某个 agent 增加第三个账号或给其他 agent 增加第二个账号，建议按以下方式处理：

- 先做 `auth-profiles.json` 备份
- 登录完成后立即检查 profile id 是否被写成 `openai-codex:default`
- 如发生覆盖，再手工整理为独立 profile，并补 `auth order`

## 影响与遗留事项

本次 `models auth login` 过程会同步写 sibling agents，因此除 `main` 外，另外两个 agent 当前状态为：

- `project-task`：仍为单账号，且 `openai-codex:default` 已是新账号
- `mc-gateway-520239c5-b9b5-475e-b460-bc9f59571f95`：仍为单账号，且 `openai-codex:default` 已是新账号

也就是说，本次只把 `main` 整理成了“双账号并列”结构；其他两个 agent 还没有同步整理。

如果需要一致化，还需要额外处理：

- `~/.openclaw/agents/project-task/agent/auth-profiles.json`
- `~/.openclaw/agents/mc-gateway-520239c5-b9b5-475e-b460-bc9f59571f95/agent/auth-profiles.json`

## 涉及文件

### 文档记录

- `docs/02-问题修复/02-main-agent添加第二个ChatGPT账号_20260307_2007.md`

### 运行时配置

- `~/.openclaw/agents/main/agent/auth-profiles.json`
- `~/.openclaw/openclaw.json`

### 本次新增备份

- `~/.openclaw/agents/main/agent/auth-profiles.json.codex-pre-second-account-20260307120325.bak`
- `~/.openclaw/openclaw.json.codex-pre-second-account-20260307120325.bak`
