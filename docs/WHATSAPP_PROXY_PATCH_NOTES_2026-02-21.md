# WhatsApp 代理接入修改说明（2026-02-21）

## 1. 改了什么

本次仅修改了一个文件：

- `src/web/session.ts`

核心变更：

1. 新增 `HttpsProxyAgent` 引入
2. 新增 `resolveWhatsAppProxyAgent()`：
   - 读取 `HTTPS_PROXY` 或 `HTTP_PROXY`
   - 尝试构造代理 agent
   - 失败时安全降级（返回 `undefined`）
3. 在创建 Baileys socket 时注入代理：
   - `agent`
   - `fetchAgent`

对应 commit：`f1ffe476411b7d09c4ac2e373ee1758503ea9ee8`

---

## 2. 为什么要改

之前在代理网络环境下，WhatsApp Web/Baileys 连接会出现不稳定或无法连通问题。
根因是：虽然系统层可能设置了代理环境变量，但 socket 请求路径没有显式绑定代理 agent。

---

## 3. 修改后的作用

- 在设置 `HTTPS_PROXY`/`HTTP_PROXY` 时，WhatsApp 连接将通过代理发起
- 在没有代理或代理配置异常时，不会崩溃，继续走原默认直连逻辑
- 对现有无代理用户行为保持兼容

---

## 4. 怎么使用

### 4.1 配置代理环境变量（示例）

```bash
export HTTPS_PROXY=http://127.0.0.1:7890
# 或
export HTTP_PROXY=http://127.0.0.1:7890
```

### 4.2 启动 OpenClaw

```bash
openclaw gateway start
# 或正常启动你的服务进程
```

### 4.3 验证

- 查看 WhatsApp 是否正常连接并保持稳定
- 若代理无效，代码会自动回退，不影响基本启动

---

## 5. 风险与兼容性

- 仅对 `session.ts` 连接构建路径做了增量修改，影响面小
- 代理 URL 非法时会安全忽略，避免因配置错误导致进程崩溃
- 如果未来 Baileys 参数签名变化，需要同步检查 `agent/fetchAgent` 字段
