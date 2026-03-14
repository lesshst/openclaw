import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { captureEnv } from "../../test-utils/env.js";
import { resolveApiKeyForProfile } from "./oauth.js";
import { resolveAuthProfileOrder } from "./order.js";
import {
  clearRuntimeAuthProfileStoreSnapshots,
  ensureAuthProfileStore,
  saveAuthProfileStore,
} from "./store.js";
import type { AuthProfileStore } from "./types.js";

const { getOAuthApiKeyMock } = vi.hoisted(() => ({
  getOAuthApiKeyMock: vi.fn(async () => {
    throw new Error("Failed to extract accountId from token");
  }),
}));

vi.mock("@mariozechner/pi-ai/oauth", () => ({
  getOAuthApiKey: getOAuthApiKeyMock,
  getOAuthProviders: () => [
    { id: "openai-codex", envApiKey: "OPENAI_API_KEY", oauthTokenEnv: "OPENAI_OAUTH_TOKEN" }, // pragma: allowlist secret
    { id: "anthropic", envApiKey: "ANTHROPIC_API_KEY", oauthTokenEnv: "ANTHROPIC_OAUTH_TOKEN" }, // pragma: allowlist secret
  ],
}));

function createExpiredOauthStore(params: {
  profileId: string;
  provider: string;
  access?: string;
}): AuthProfileStore {
  return {
    version: 1,
    profiles: {
      [params.profileId]: {
        type: "oauth",
        provider: params.provider,
        access: params.access ?? "cached-access-token",
        refresh: "refresh-token",
        expires: Date.now() - 60_000,
      },
    },
  };
}

describe("resolveApiKeyForProfile openai-codex refresh fallback", () => {
  const envSnapshot = captureEnv([
    "OPENCLAW_STATE_DIR",
    "OPENCLAW_AGENT_DIR",
    "PI_CODING_AGENT_DIR",
  ]);
  let tempRoot = "";
  let agentDir = "";

  beforeEach(async () => {
    getOAuthApiKeyMock.mockClear();
    clearRuntimeAuthProfileStoreSnapshots();
    tempRoot = await fs.mkdtemp(path.join(os.tmpdir(), "openclaw-codex-refresh-fallback-"));
    agentDir = path.join(tempRoot, "agents", "main", "agent");
    await fs.mkdir(agentDir, { recursive: true });
    process.env.OPENCLAW_STATE_DIR = tempRoot;
    process.env.OPENCLAW_AGENT_DIR = agentDir;
    process.env.PI_CODING_AGENT_DIR = agentDir;
  });

  afterEach(async () => {
    clearRuntimeAuthProfileStoreSnapshots();
    envSnapshot.restore();
    await fs.rm(tempRoot, { recursive: true, force: true });
  });

  it("falls back to cached access token when openai-codex refresh fails on accountId extraction", async () => {
    const profileId = "openai-codex:default";
    saveAuthProfileStore(
      createExpiredOauthStore({
        profileId,
        provider: "openai-codex",
      }),
      agentDir,
    );

    const result = await resolveApiKeyForProfile({
      store: ensureAuthProfileStore(agentDir),
      profileId,
      agentDir,
    });

    expect(result).toEqual({
      apiKey: "cached-access-token", // pragma: allowlist secret
      provider: "openai-codex",
      email: undefined,
    });
    expect(getOAuthApiKeyMock).toHaveBeenCalledTimes(1);
  });

  it("keeps throwing for non-codex providers on the same refresh error", async () => {
    const profileId = "anthropic:default";
    saveAuthProfileStore(
      createExpiredOauthStore({
        profileId,
        provider: "anthropic",
      }),
      agentDir,
    );

    await expect(
      resolveApiKeyForProfile({
        store: ensureAuthProfileStore(agentDir),
        profileId,
        agentDir,
      }),
    ).rejects.toThrow(/OAuth token refresh failed for anthropic/);
  });

  it("does not use fallback for unrelated openai-codex refresh errors", async () => {
    const profileId = "openai-codex:default";
    saveAuthProfileStore(
      createExpiredOauthStore({
        profileId,
        provider: "openai-codex",
      }),
      agentDir,
    );
    getOAuthApiKeyMock.mockImplementationOnce(async () => {
      throw new Error("invalid_grant");
    });

    await expect(
      resolveApiKeyForProfile({
        store: ensureAuthProfileStore(agentDir),
        profileId,
        agentDir,
      }),
    ).rejects.toThrow(/OAuth token refresh failed for openai-codex/);
  });

  it("disables permanently invalid refresh-token-reused profiles so ordering skips them", async () => {
    const brokenProfileId = "openai-codex:default";
    const healthyProfileId = "openai-codex:plus";
    saveAuthProfileStore(
      {
        version: 1,
        profiles: {
          [brokenProfileId]: {
            type: "oauth",
            provider: "openai-codex",
            access: "expired-access-token",
            refresh: "reused-refresh-token",
            expires: Date.now() - 60_000,
          },
          [healthyProfileId]: {
            type: "oauth",
            provider: "openai-codex",
            access: "healthy-access-token",
            refresh: "healthy-refresh-token",
            expires: Date.now() + 60_000,
          },
        },
        order: {
          "openai-codex": [brokenProfileId, healthyProfileId],
        },
      },
      agentDir,
    );
    getOAuthApiKeyMock.mockImplementationOnce(async () => {
      throw new Error(
        '401 {"error":{"message":"Your refresh token has already been used to generate a new access token. Please try signing in again.","type":"invalid_request_error","code":"refresh_token_reused"}}',
      );
    });

    await expect(
      resolveApiKeyForProfile({
        store: ensureAuthProfileStore(agentDir),
        profileId: brokenProfileId,
        agentDir,
      }),
    ).resolves.toEqual({
      apiKey: "healthy-access-token",
      provider: "openai-codex",
      email: undefined,
    });

    clearRuntimeAuthProfileStoreSnapshots();
    const reloadedStore = ensureAuthProfileStore(agentDir);
    expect(reloadedStore.usageStats?.[brokenProfileId]?.disabledReason).toBe("auth_permanent");
    expect((reloadedStore.usageStats?.[brokenProfileId]?.disabledUntil ?? 0) > Date.now()).toBe(
      true,
    );
    expect(resolveAuthProfileOrder({ store: reloadedStore, provider: "openai-codex" })).toEqual([
      healthyProfileId,
      brokenProfileId,
    ]);
  });
});
