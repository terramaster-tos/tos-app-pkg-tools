# TerraMaster Developer Platform · Agent API

**Languages:** **English** · [简体中文](./README.zh-CN.md)

The TerraMaster Developer Platform Agent API lets you manage apps and versions on the platform programmatically. It is intended for AI agents, command-line tools, and CI/CD pipelines that publish and maintain apps without going through the web portal.

With this API you can:

- View and create apps, update an app's repository URL, and delete apps
- View an app's repository releases and its versions, including the review timeline of each version
- Create a version (asynchronous, two-stage: validate, then confirm)
- Withdraw a version under review, or request takedown of a published version

Every endpoint described here is implemented. This document is the complete interface specification.

---

## Table of contents

- [1. Overview](#1-overview)
- [2. Base URL and authentication](#2-base-url-and-authentication)
- [3. Scopes](#3-scopes)
- [4. Identifiers and status values](#4-identifiers-and-status-values)
- [5. Response conventions](#5-response-conventions)
- [6. API reference](#6-api-reference)
- [7. Errors](#7-errors)
- [8. Complete workflow](#8-complete-workflow)
- [9. Standards and conventions](#9-standards-and-conventions)
- [10. Resources](#10-resources)

---

## 1. Overview

### Base URL

```text
https://api-developer.terra-master.com
```

All endpoints live under the `/v1` path prefix.

### Authentication at a glance

Every `/v1/*` request is authenticated with an API Token sent as a Bearer credential:

```bash
-H "Authorization: Bearer ${TDP_API_TOKEN}"
```

**API Tokens only.** Web session tokens are not accepted. An API Token must be issued by the Developer in advance, and its complete value is shown **only once**, at the moment it is issued.

### What a token can reach

A token acts on behalf of the Developer who issued it, and can only access Apps and Versions owned by that Developer. The set of operations it may perform is limited by its [Scopes](#3-scopes).

---

## 2. Base URL and authentication

### 2.1 Configuration through environment variables

Clients read their configuration from the environment. Two variables are used:

| Variable | Required | Default | Description |
| --- | :-: | --- | --- |
| `TDP_BASE_URL` | No | `https://api-developer.terra-master.com` | API base URL. Override only when targeting a non-production environment. |
| `TDP_API_TOKEN` | **Yes** | — | The API Token, used as the Bearer credential. |

Two rules apply to every client, including AI agents:

1. **Never pass the token as a command-line argument.** Read it from the environment. Command-line arguments end up in shell history, process listings, and logs.
2. **Never print, log, or echo the token value** in output, responses, or conversation.

When `TDP_BASE_URL` is unset, fall back to the production URL. Ask the user to configure something only when `TDP_API_TOKEN` is missing:

```bash
export TDP_BASE_URL="${TDP_BASE_URL:-https://api-developer.terra-master.com}"
: "${TDP_API_TOKEN:?TDP_API_TOKEN is required}"
```

### 2.2 Request headers

| Header | Value | Required |
| --- | --- | :-: |
| `Authorization` | `Bearer ${TDP_API_TOKEN}` | Yes |
| `Content-Type` | `application/json` | Only on requests with a JSON body |
| `Accept` | `application/json, application/problem+json` | Recommended |
| `Accept-Language` | `zh` / `en` (any `zh*` variant → Chinese, anything else → English) | Optional |

`Accept-Language` controls the language of **human-readable** response text — error `title`/`detail`/`details.advice`, and task-step `title`/`message`/`advice`. Machine-readable fields (`code`, `status`, step field names, `details.retry_after`) are never localized.

### 2.3 Verify your identity first

Before any other operation, call `GET /v1/whoami` to confirm which Developer the token represents and which Scopes it carries:

```bash
curl --fail-with-body --silent --show-error \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  "${TDP_BASE_URL}/v1/whoami"
```

The `developer` field identifies the Developer; `token.scopes` lists the token's Scopes. Checking this first turns a confusing `403` deep inside a workflow into an immediate, actionable answer.

### 2.4 Issuing an API Token

API Tokens are issued in the web portal, on the **API Keys** page of the Developer Platform:

1. Open the API Keys page and choose **Create Key**.
2. Select the validity period and the [Scopes](#3-scopes) the key should carry, then submit.
3. The system generates the token. **The plaintext value is displayed only once** — copy it immediately. After the dialog is closed it cannot be viewed again from the list.
4. Store the value in the `TDP_API_TOKEN` environment variable of the machine or CI runner that will call the API.

### 2.5 Token security

- Treat a token as a password. Anyone holding it can act as the issuing Developer, within the limits of its Scopes.
- Never commit a token to a repository, embed it in a client-side or public environment, or expose it in screenshots or chat.
- There is no disable/enable switch. A token that has leaked, or is no longer needed, must be **deleted**.
- A token's validity period cannot be changed after creation. To obtain a token with a different lifetime, delete it and create a new one.
- Grant the minimum set of Scopes the workload actually needs.

---

## 3. Scopes

Each API Token carries a set of Scopes chosen at creation time. A request is rejected when the token lacks the Scope required by the endpoint.

### 3.1 Operation-to-scope mapping

| Operation | Required scope |
| --- | --- |
| View Apps | `app:read` |
| View an App's Release list | `app:read` |
| Create an App | `app:write` |
| Update an App's repository URL | `app:write` |
| Delete an App | `app:delete` |
| View Versions, Version Creation Tasks, or Parse Results | `version:read` |
| View a Version's review timeline | `version:read` |
| Create, confirm, or cancel Version Creation Tasks | `version:write` |
| Withdraw a review or request Version takedown | `version:delete` |

### 3.2 Scope rules

- **Calling `GET /v1/apps` carries the `app:read` permission requirement** — but `app:read` is the global minimum permission: **any token holding at least one valid Scope automatically satisfies it.** For example, a token with only `version:read` can list and read Apps, and gets `200` from `GET /v1/apps`.
- **The requirement being satisfied does not change the token.** The `token.scopes` list returned by `GET /v1/whoami` is exactly what was stored at issuance; `app:read` is **not** added to it. A token without `app:read` in `token.scopes` can still read Apps.
- Tokens issued through the platform UI always include `app:read` (the UI keeps it permanently selected).
- **`version:write` and `version:delete` each include `version:read`.** A token that can create or withdraw a version can also read versions and tasks.
- **`version:delete` does not include `version:write`.** Withdrawing a review and requesting a takedown are destructive and are granted separately from creation.
- **No App Scope includes a Version Scope.** Being able to manage apps does not grant access to versions.

A token must carry at least one Scope. In the portal, Scopes are selected per group (App / Version) and are multi-select; within a group, `read` cannot be deselected while `write` or `delete` is selected.

---

## 4. Identifiers and status values

### 4.1 Identifiers

Three different identifiers appear in this API. Mixing them up is the most common integration error.

| Identifier | Where it appears | What it is |
| --- | --- | --- |
| `{app_id}` | App paths | The App **entity UUID**, taken from the `id` field of an App response. It is neither the business field `app_id` nor the app name. |
| `{version_id}` | Version paths | The Version **entity UUID**, taken from the `id` field of a Version response. It is not the version tag. |
| `{task_id}` | Task paths | The `task_id` returned when Version Creation starts. |

A Version tag is a free-form string of at most **128 characters**. Tags do not need to be ordered or unique — the same tag can appear on more than one version. Always select and act on a version by its entity UUID.

### 4.2 Version status

| Value | Meaning | Destructive operation available |
| ---: | --- | --- |
| `0` | Reviewing | Withdraw review |
| `1` | Approved *(historical — not produced by the current workflow, never returned)* | None |
| `2` | Published | Request takedown |
| `3` | Rejected | None |
| `4` | Withdrawn | None |
| `5` | Takedown pending | Wait for administrator review |
| `6` | Taken down | None |
| `7` | Force-taken-down | None |

Status `1` is a historical value. The current workflow never produces it, and there is no data that would make the API return it. It stays in this table so that, should you ever encounter it, you know what it is: **treat it as a terminal state** — do not fire any destructive operation at it, and do not treat it as "published". Build action logic on `0` and `2` only.

---

## 5. Response conventions

Successful responses use `application/json`, except when cancelling a Version Creation Task, which returns no body.

| Operation | HTTP status | Response body |
| --- | ---: | --- |
| Get identity | `200` | `{"developer": {...}, "token": {...}}` |
| List Apps or Versions | `200` | JSON array; `[]` when empty |
| Get or create an App | `200` | App object |
| List an App's Releases | `200` | `{"total": N, "items": [...]}` |
| Delete an App | `200` | `{"message":"deleted"}` |
| Start Version Creation | `202` | `{"task_id":"<UUID>"}` |
| Get task status | `200` | Task status object |
| Cancel a task | `204` | No response body |
| Get Parse Result | `200` | Parse Result object |
| Confirm a task | `200` | Created Version object; entity ID is in `id` |
| Withdraw a review | `200` | `{"message":"withdrawn"}` |
| Request takedown | `200` | `{"message":"taken down"}` |

Two consequences worth noting:

- **Determine the result from the JSON fields, not from the status code alone.** Several operations return `200` regardless of nuance in the outcome.
- **Only `204` guarantees an empty response body.** Every other success response must be read. `202` in particular means the work has been *accepted*, not *completed*.

### Time fields

Timestamp formats are **intentionally not unified** across the API. The rule is consistent within each object, so a client type never needs a `string | number` union — but you must use the right format per object:

| Object | Fields | Format |
| --- | --- | --- |
| App (`GET /v1/apps`, `GET /v1/apps/{app_id}`, `POST /v1/apps`, `PUT /v1/apps/{app_id}/repo`) | `created_at`, `deleted_at` | **Unix seconds** (integer). `deleted_at` is `0` when the App is not deleted. |
| Version (list, single, Confirm response) | `created_at` | **Unix seconds** (integer) |
| Release (`GET /v1/apps/{app_id}/releases`) | `created_at` | **Unix seconds** (integer) |
| Review timeline nodes (`GET /v1/apps/{app_id}/versions/{version_id}/reviews`) | `time` | **Unix seconds** (integer); `0` means the state was never reached |
| Token metadata (`GET /v1/whoami` → `token`) | `created_at`, `expires_at`, `last_used_at` | **RFC 3339 string** (UTC, `Z` suffix, may carry fractional seconds). `last_used_at` can be `null`. |

There is no `updated_at` anywhere in this API — the backend does not expose update timestamps.

---

## 6. API reference

Seventeen endpoints, in five groups.

| Group | Endpoints |
| --- | --- |
| Identity | `GET /v1/whoami` |
| Apps | `GET /v1/apps`, `GET /v1/apps/{app_id}`, `POST /v1/apps`, `PUT /v1/apps/{app_id}/repo`, `GET /v1/apps/{app_id}/releases`, `DELETE /v1/apps/{app_id}` |
| Versions | `GET /v1/apps/{app_id}/versions`, `GET /v1/apps/{app_id}/versions/{version_id}`, `GET /v1/apps/{app_id}/versions/{version_id}/reviews` |
| Version Creation | `POST /v1/apps/{app_id}/versions`, `GET .../tasks/{task_id}`, `GET .../tasks/{task_id}/result`, `POST .../tasks/{task_id}/confirm`, `POST .../tasks/{task_id}/cancel` |
| Version Disposal | `POST .../versions/{version_id}/withdraw`, `DELETE .../versions/{version_id}` |

> The response examples below are **excerpts**: they show the fields this document describes. Do not build logic against fields that are not listed here.

### 6.1 Identity

#### `GET /v1/whoami`

Returns the Developer represented by the token, and the token's own metadata.

**Required scope:** valid API Token (no additional scope).

```bash
curl --fail-with-body --silent --show-error \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  "${TDP_BASE_URL}/v1/whoami"
```

**Response** `200` — excerpt:

```json
{
  "developer": {
    "id": 12345,
    "name": "Example Developer"
  },
  "token": {
    "scopes": ["app:read", "app:write", "version:read", "version:write"],
    "created_at": "2026-01-10T08:00:00Z",
    "expires_at": "2027-01-10T08:00:00Z",
    "last_used_at": "2026-01-10T10:12:00Z"
  }
}
```

| Field | Description |
| --- | --- |
| `developer` | The Developer account this token acts for. All resource access is limited to this Developer. |
| `token.scopes` | The Scopes carried by the token, exactly as stored at issuance. Implied Scopes are not echoed back — see [Scope rules](#32-scope-rules). |
| `token.created_at`, `token.expires_at`, `token.last_used_at` | Token metadata, **RFC 3339 strings**. `last_used_at` is `null` until the token is first used. |

**Errors:** `401` `110301`.

### 6.2 Apps

#### `GET /v1/apps`

Lists the Developer's Apps.

**Required scope:** `app:read`.

**Query parameters**

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `kind` | string | `all` | Filter by package type. One of `all`, `deb`, `docker`. |

```bash
curl --fail-with-body --silent --show-error \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  "${TDP_BASE_URL}/v1/apps?kind=all"
```

**Response** `200` — JSON array; `[]` when the Developer has no apps.

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "app_id": "com.example.myapp",
    "name": "My App",
    "kind": ".deb",
    "status": 0,
    "created_at": 1767960000
  }
]
```

> **`kind` has two notations.** In *this endpoint's response* `kind` is a display string — `.deb` or `docker image`. Every other endpoint (create App, get App, update repo) uses the plain form `deb` / `docker` in both requests and responses. Never compare or filter a `kind` value from this list against a `kind` value from another endpoint without normalizing first.

`created_at` is Unix seconds. Save the `id` field — every App and Version path uses this entity UUID. To select an App by its business `app_id`:

```bash
export APP_ID="$({
  curl --fail-with-body --silent --show-error \
    -H "Authorization: Bearer ${TDP_API_TOKEN}" \
    "${TDP_BASE_URL}/v1/apps?kind=all"
} | jq -r '.[] | select(.app_id == "com.example.myapp") | .id' | sed -n '1p')"

test -n "${APP_ID}" && test "${APP_ID}" != 'null'
printf 'APP_ID=%s\n' "${APP_ID}"
```

**Errors:** `401` `110301`, `403` `110401`.

#### `GET /v1/apps/{app_id}`

Returns one App.

**Required scope:** `app:read`.

| Path parameter | Description |
| --- | --- |
| `app_id` | App entity UUID. |

```bash
export APP_ID='550e8400-e29b-41d4-a716-446655440000'

curl --fail-with-body --silent --show-error \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  "${TDP_BASE_URL}/v1/apps/${APP_ID}"
```

**Response** `200` — an App object. Unlike the list response, `kind` uses the plain form `deb` / `docker`. `created_at` is Unix seconds; `deleted_at` is `0` for a live App.

**Errors:** `401` `110301`, `403` `110401`, `404` `300501`.

#### `POST /v1/apps`

Creates an App.

**Required scope:** `app:write`.

**Request body**

| Field | Type | Required | Description |
| --- | --- | :-: | --- |
| `app_id` | string | Yes | Business identifier, for example `com.example.myapp`. |
| `kind` | string | Yes | `deb` or `docker`. |
| `platform` | string | Yes | `x86_64` or `aarch64`. |
| `repo` | string | Yes | HTTPS repository URL on a supported hosting provider. |

```bash
APP_JSON="$({
  curl --fail-with-body --silent --show-error \
    -X POST \
    -H "Authorization: Bearer ${TDP_API_TOKEN}" \
    -H 'Content-Type: application/json' \
    --data '{
      "app_id": "com.example.myapp",
      "kind": "deb",
      "platform": "x86_64",
      "repo": "https://github.com/example/myapp"
    }' \
    "${TDP_BASE_URL}/v1/apps"
})"

printf '%s\n' "${APP_JSON}" | jq .
export APP_ID="$(printf '%s\n' "${APP_JSON}" | jq -er '.id')"
```

**Response** `200` — the created App object.

Keep the response field `id`. The business `app_id` is a label and cannot be used in place of the entity UUID in later request paths.

**Errors:** `400` `100101`, `400` `200201` / `300201` (input validation), `401` `110301`, `403` `110401`, `409` `300602` (App ID already registered by you), `409` `300603` (App ID already used for another kind), `409` `300604` (App ID belongs to another Developer and can never be registered again).

#### `PUT /v1/apps/{app_id}/repo`

Updates the repository URL an App pulls its packages from.

**Required scope:** `app:write`.

| Path parameter | Description |
| --- | --- |
| `app_id` | App entity UUID. |

**Request body**

| Field | Type | Required | Description |
| --- | --- | :-: | --- |
| `repo` | string | Yes | New repository URL. Must be HTTPS, on a supported hosting provider, in a recognizable `owner/repo` form. |

```bash
curl --fail-with-body --silent --show-error \
  -X PUT \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  -H 'Content-Type: application/json' \
  --data '{"repo":"https://github.com/example/myapp-v2"}' \
  "${TDP_BASE_URL}/v1/apps/${APP_ID}/repo"
```

**Response** `200` — the App object with the updated `repo` (same shape as [Get a single App](#get-v1appsapp_id)).

Two behaviours worth knowing:

- **Existing Versions are unaffected** — their package files are already in object storage. Only Versions created *after* the change are pulled from the new repository.
- **Submitting the current value is idempotent.**

**Errors:** `400` `200201` (malformed JSON or invalid repository URL), `401` `110301`, `403` `110401`, `404` `300501`.

#### `GET /v1/apps/{app_id}/releases`

Fetches the Release list of the App's code repository (GitHub/Gitee), newest first, each Release with its file (assets) list. Use it to verify a real `browser_download_url` before creating a Version.

**Required scope:** `app:read`.

**Query parameters**

| Name | Type | Description |
| --- | --- | --- |
| `page` | integer | Page number, starting at `1`. |
| `per_page` | integer | Items per page. |
| `refresh` | string | Set to `true` to bypass the cache and re-fetch immediately. Limited to **1 use per Developer per minute**. |

```bash
curl --fail-with-body --silent --show-error \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  "${TDP_BASE_URL}/v1/apps/${APP_ID}/releases?page=1&per_page=5"
```

**Response** `200` — `{"total": N, "items": [...]}`. `items[].files[].browser_download_url` is a legal value for the `browser_download_url` field when creating a Version. Release `created_at` is Unix seconds.

**Prefer the repository platform's own API when you can** — GitHub: `GET https://api.github.com/repos/{owner}/{repo}/releases`, Gitee: `GET https://gitee.com/api/v5/repos/{owner}/{repo}/releases` (`{owner}/{repo}` taken from the App's `repo` URL). Call this endpoint only when the official API is unavailable (for example, no repository credentials), and note that it is **strictly rate-limited**.

**Rate limits and caching**

- The server caches the full list per App for **5 minutes**.
- Only requests that trigger a full fetch consume quota: **1 per Developer per 10 seconds**. Cache hits are not rate-limited.
- A full fetch covers at most the most recent **5000 Releases**; beyond that, `total` reflects the truncated snapshot size.
- When quota is exhausted: a normal fetch falls back to stale cache if one exists, and returns `429` `300801` if not; a `refresh=true` fetch always returns `429` `340801`. `details.retry_after` gives the exact number of seconds to wait (≤10 for normal fetches, ≤60 for forced refreshes); `details.advice` explains the fix.
- If the upstream repository fails: a normal fetch falls back to stale cache; a forced refresh fails outright — stale data is never used to disguise an unfinished refresh. Failure returns `502` `340901`.

**Errors:** `401` `110301`, `403` `110401`, `404` `300501`, `429` `300801` / `340801`, `502`/`503` `340901`.

#### `DELETE /v1/apps/{app_id}`

Deletes an App **immediately**. This is destructive and irreversible.

**Required scope:** `app:delete`.

**Read the App first and verify that its `id` and `app_id` are the intended target:**

```bash
curl --fail-with-body --silent --show-error \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  "${TDP_BASE_URL}/v1/apps/${APP_ID}" | jq '{id, app_id, name, status}'
```

Then delete:

```bash
curl --fail-with-body --silent --show-error \
  -X DELETE \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  "${TDP_BASE_URL}/v1/apps/${APP_ID}"
```

**Response** `200`:

```json
{"message":"deleted"}
```

This response means deletion completed. Do not repeat the request.

**Errors:** `401` `110301`, `403` `110401`, `404` `300501`, `409` `300601`.

**When the App cannot be deleted — `409` `300601`.** The App has a Version that is reviewing, published, or pending takedown. A published version must not disappear behind the Developer's back, so the platform blocks the deletion. The correct behaviour:

1. Stop.
2. Tell the user which Versions block the deletion, and in what states they are.
3. Explicitly ask whether to continue.
4. **Do not** automatically withdraw a review, request a takedown, or retry the deletion.
5. Only after the user confirms may you dispose of the relevant Versions as described in [section 6.5](#65-version-disposal), then retry the deletion.

### 6.3 Versions

#### `GET /v1/apps/{app_id}/versions`

Lists all Versions of an App.

**Required scope:** `version:read`.

```bash
curl --fail-with-body --silent --show-error \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions"
```

**Response** `200` — JSON array of Version objects; `[]` when the App has none.

```json
[
  {
    "id": "9c8b7a6f-0000-0000-0000-000000000000",
    "version": "1.0.0",
    "status": 2,
    "created_at": 1767960000
  }
]
```

`created_at` is Unix seconds. Save the `id` field to act on a specific version:

```bash
export VERSION_ID="$({
  curl --fail-with-body --silent --show-error \
    -H "Authorization: Bearer ${TDP_API_TOKEN}" \
    "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions"
} | jq -r '.[] | select(.version == "1.0.0") | .id' | sed -n '1p')"

test -n "${VERSION_ID}" && test "${VERSION_ID}" != 'null'
printf 'VERSION_ID=%s\n' "${VERSION_ID}"
```

**Tags can be duplicated.** Selecting by `.version` may match more than one Version. Before any destructive operation, fetch the selected Version again and verify its `id`, `version`, `status`, and `created_at`.

**Errors:** `401` `110301`, `403` `110401`, `404` `300501`.

#### `GET /v1/apps/{app_id}/versions/{version_id}`

Returns one Version.

**Required scope:** `version:read`.

| Path parameter | Description |
| --- | --- |
| `app_id` | App entity UUID. |
| `version_id` | Version entity UUID. |

```bash
curl --fail-with-body --silent --show-error \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions/${VERSION_ID}"
```

**Response** `200` — a Version object, including `id`, `version`, `status`, and `created_at`. Read `status` before choosing an operation — see [section 6.5](#65-version-disposal).

**Errors:** `401` `110301`, `403` `110401`, `404` `310501`.

#### `GET /v1/apps/{app_id}/versions/{version_id}/reviews`

Returns the review timeline of a Version: an array of timeline nodes covering all of its review tickets.

**Required scope:** `version:read`.

| Path parameter | Description |
| --- | --- |
| `app_id` | App entity UUID. |
| `version_id` | Version entity UUID. |

```bash
curl --fail-with-body --silent --show-error \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions/${VERSION_ID}/reviews"
```

**Response** `200` — JSON array of timeline nodes.

| Field | Description |
| --- | --- |
| `node` | Node type. One of `SubmitVersion`, `SubmitVersionReviewing`, `SubmitVersionApproved`, `SubmitVersionRejected`, `WithdrawVersion`, `TakeDown`, `TakeDownReviewing`, `TakeDownApproved`, `TakeDownRejected`, `TakeDownDeListed`, `ForceTakeDown`, `VersionPublishing`, `VersionPublished`. |
| `comments` | Reviewer's comment; empty string when there is none. |
| `time` | Node time, **Unix seconds**; `0` means the state was never reached. |
| `details.reviewer` | Reviewer name; empty string when not yet assigned. |
| `details.handler` | **Always an empty string on the developer side.** Do not depend on it. |

**Errors:** `401` `110301`, `403` `110401`, `404` `300501` / `310501`.

### 6.4 Version Creation

Version Creation is **asynchronous and two-stage**. It is the most involved workflow in this API, and the part that surprises most integrators: starting it does **not** create anything by itself.

```text
POST /v1/apps/{app_id}/versions      →  202, returns task_id   (no version exists yet)
GET  .../tasks/{task_id}             →  poll all_status
GET  .../tasks/{task_id}/result      →  inspect package metadata   (only when all_status = 2)
POST .../tasks/{task_id}/confirm     →  200, NOW a Version exists
```

Task retention: a **passed but unconfirmed** task is kept for **1 hour**; a **failed or already confirmed** task is kept for **10 minutes**. Each Developer can run only **one** Version Creation Task at a time.

#### `POST /v1/apps/{app_id}/versions`

Starts a Version Creation Task.

**Required scope:** `version:write`.

**Precondition:** the App must not already have a Version in review (`status=0`). If it does, the call fails with `400` `200201` — wait for that review to finish, or withdraw it first (see [section 6.5](#65-version-disposal)).

**Request body**

| Field | Type | Required | Description |
| --- | --- | :-: | --- |
| `tag` | string | Yes | Version tag, free-form, at most 128 characters. |
| `browser_download_url` | string | Yes | Direct download URL of the package file. Its host must match the App's repo host. |

```bash
TASK_JSON="$({
  curl --fail-with-body --silent --show-error \
    -X POST \
    -H "Authorization: Bearer ${TDP_API_TOKEN}" \
    -H 'Content-Type: application/json' \
    --data '{
      "tag": "1.0.0",
      "browser_download_url": "https://github.com/example/myapp/releases/download/1.0.0/com.example.myapp_x86_64.deb"
    }' \
    "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions"
})"

printf '%s\n' "${TASK_JSON}" | jq .
export TASK_ID="$(printf '%s\n' "${TASK_JSON}" | jq -er '.task_id')"
```

**Response** `202`:

```json
{"task_id":"b6a1c9de-0000-0000-0000-000000000000"}
```

No Version entity exists at this point. The `202` means the task was accepted, not that the package is valid.

**Errors:** `400` `100101`, `400` `200201` (a Version of this App is already under review, or other input validation), `401` `110301`, `403` `110401`, `404` `300501`, `429` `310801`, `503` `990301`.

#### `GET /v1/apps/{app_id}/versions/tasks/{task_id}`

Polls a Version Creation Task.

**Required scope:** `version:read`.

| Path parameter | Description |
| --- | --- |
| `app_id` | App entity UUID. |
| `task_id` | Task UUID returned by the creation call. |

```bash
curl --fail-with-body --silent --show-error \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions/tasks/${TASK_ID}" | jq .
```

**Response** `200` — task status object. **A failed task does not produce an HTTP error**: status polling always returns `200`, and the failure lives inside the body (see below).

**Top-level fields:** `all_status`, `steps`, and `version_id` (present only after a successful Confirm — see below).

`all_status` values:

| Value | Meaning | What to do |
| ---: | --- | --- |
| `0` | waiting | Keep polling. |
| `1` | checking | Keep polling. |
| `2` | passed | Read the Parse Result, then confirm. |
| `3` | failed | Stop. Inspect the failed steps' `message` and `advice`. **Never confirm a failed task.** |

**`version_id`** appears (non-empty) only after Confirm succeeds. `all_status = 2` with an **empty** `version_id` means: the task has passed and is waiting for you to Confirm.

**The `steps` object.** Two stages; stage and step `title` values are localized per `Accept-Language` (the table below shows the English fallbacks):

| Stage | Step field | Step title | Semantics |
| --- | --- | --- | --- |
| `download_step` | `package_download_failed` | Application Package Download | Run in order; any failed step ends the task |
| | `invalid_package_format` | Application Package Format Validation | Same |
| | `package_unzip_failed` | Package Unzip | Same |
| `parse_step` | `missing_required_files` | Required Files Completeness | Run in parallel; every response carries all step results |
| | `invalid_config_ini` | config.ini JSON Format | Same |
| | `app_id_mismatch` | config.ini ID Consistency | Same |
| | `invalid_application_type` | config.ini Application Type | Same |
| | `platform_mismatch` | config.ini Platform Consistency | Same |
| | `invalid_language_files` | app.lang Format | Same |
| | `icon_validation_failed` | Icon Compliance | Same |

Both levels are **fixed enums** — the keys above never change, and every response carries all of them. Each step object always contains **four** fields:

| Field | Description |
| --- | --- |
| `title` | Localized step title. |
| `status` | Same semantics as `all_status`: `0` waiting / `1` checking / `2` passed / `3` failed. |
| `message` | What went wrong. Non-empty **only when `status=3`**; otherwise `""`. |
| `advice` | What to do about it. Non-empty **only when `status=3`**; may be multi-line. Otherwise `""`. |

Example — a failed task:

```json
{
  "all_status": 3,
  "steps": {
    "download_step": {
      "title": "Download Step",
      "package_download_failed": {
        "title": "Application Package Download",
        "status": 3,
        "message": "download failed after repeated attempts",
        "advice": "check that browser_download_url is reachable and its host matches the app's repo"
      },
      "invalid_package_format": {
        "title": "Application Package Format Validation",
        "status": 0,
        "message": "",
        "advice": ""
      },
      "package_unzip_failed": {
        "title": "Package Unzip",
        "status": 0,
        "message": "",
        "advice": ""
      }
    },
    "parse_step": {
      "title": "Parse Step",
      "missing_required_files": {
        "title": "Required Files Completeness",
        "status": 0,
        "message": "",
        "advice": ""
      }
    }
  }
}
```

(The example truncates `parse_step` — real responses carry all seven keys.)

Because the key set is fixed you can index directly into the failing step instead of walking the dictionary — but do **not** rely on key order: JSON objects are unordered. Surface both `message` and `advice` to the user rather than a bare "submission failed".

**Do not poll aggressively.** A two-second interval is recommended. `all_status` is the only value that determines whether the task has finished; do not infer completion from individual step states.

**Errors:** `401` `110301`, `403` `110401`, `404` `310502`.

#### `GET /v1/apps/{app_id}/versions/tasks/{task_id}/result`

Returns the Parse Result — the package metadata the platform extracted. **Call this only when `all_status == 2`.** Calling it earlier fails with `409` `310601`.

**Required scope:** `version:read`.

```bash
curl --fail-with-body --silent --show-error \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions/tasks/${TASK_ID}/result" | jq .
```

**Response** `200` — Parse Result object. Fields include:

| Field | Description |
| --- | --- |
| `app_name` | Application name read from the package. |
| `app_desc` | Application description read from the package. |
| `version_number` | Version number read from the package. |
| `platform` | Target architecture. |
| `file_size` | Package size. |
| `file_hash` | Package hash. |
| `release_notes` | Release notes. |
| `category` | Application category. |
| `icon` | Icon. **May be a large inline data URL** — do not assume it is a short link, and avoid printing it in full to a terminal. |

**Verify these fields before confirming.** This is the last point at which nothing has been created yet: catching a wrong architecture or version number here costs a retry, whereas catching it later costs a withdrawal and a new submission.

**Errors:** `401` `110301`, `403` `110401`, `404` `310502`, `409` `310601`.

#### `POST /v1/apps/{app_id}/versions/tasks/{task_id}/confirm`

Confirms a task and creates the Version.

**Required scope:** `version:write`.

Confirm only when the Parse Result is correct.

```bash
VERSION_JSON="$({
  curl --fail-with-body --silent --show-error \
    -X POST \
    -H "Authorization: Bearer ${TDP_API_TOKEN}" \
    "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions/tasks/${TASK_ID}/confirm"
})"

printf '%s\n' "${VERSION_JSON}" | jq .
export VERSION_ID="$(printf '%s\n' "${VERSION_JSON}" | jq -er '.id')"
```

**Response** `200` — the created Version object; the entity UUID is in `id`.

**Confirmation is idempotent.** After an ambiguous network failure, retry with the same `task_id`; a successful retry returns the Version created by the first confirmation, not a duplicate. Design your client so that an unknown outcome leads to a retry, not to a fresh task.

A newly confirmed Version starts in reviewing status (`status=0`) and enters the review workflow.

**Errors:** `401` `110301`, `403` `110401`, `404` `310502`, `409` `310601`.

#### `POST /v1/apps/{app_id}/versions/tasks/{task_id}/cancel`

Cancels an unconfirmed task.

**Required scope:** `version:write`.

Use this when the Parse Result is not what you expected and you do not want the Version created.

```bash
curl --fail-with-body --silent --show-error \
  -X POST \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions/tasks/${TASK_ID}/cancel"
```

**Response** `204` — no response body.

The task is removed immediately; subsequent requests for that `task_id` return `404`. **A confirmed task cannot be cancelled.**

**Errors:** `401` `110301`, `403` `110401`, `404` `310502`, `409` `310601`.

### 6.5 Version Disposal

There is **no endpoint that unconditionally deletes a Version immediately.** Deleting a version would remove a package that users may already have installed. Disposal is therefore state-dependent: read the Version's `status` first, then choose the valid operation.

```bash
VERSION_JSON="$({
  curl --fail-with-body --silent --show-error \
    -H "Authorization: Bearer ${TDP_API_TOKEN}" \
    "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions/${VERSION_ID}"
})"

printf '%s\n' "${VERSION_JSON}" | jq '{id, version, status, created_at}'
```

| Current status | Valid operation |
| --- | --- |
| `0` Reviewing | [Withdraw the review](#withdraw-a-reviewing-version) |
| `2` Published | [Request takedown](#request-takedown-of-a-published-version) |
| any other | No destructive operation is available |

#### Withdraw a reviewing Version

**Endpoint:** `POST /v1/apps/{app_id}/versions/{version_id}/withdraw`

Valid only for `status=0`.

**Required scope:** `version:delete`.

Withdrawal is **irreversible** and changes the Version to withdrawn (`status=4`).

```bash
curl --fail-with-body --silent --show-error \
  -X POST \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  -H 'Content-Type: application/json' \
  --data '{"comments":"Changes are required; withdraw this review"}' \
  "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions/${VERSION_ID}/withdraw"
```

**Request body**

| Field | Type | Required | Description |
| --- | --- | :-: | --- |
| `comments` | string | Yes | Reason for the withdrawal. |

**Response** `200`:

```json
{"message":"withdrawn"}
```

**Errors:** `400` `220201` (input validation, such as missing comments), `401` `110301`, `403` `110401`, `404` `310501`, `409` `220601`.

#### Request takedown of a published Version

**Endpoint:** `DELETE /v1/apps/{app_id}/versions/{version_id}`

Valid only for `status=2`.

**Required scope:** `version:delete`.

`DELETE` here does **not** delete the Version. It creates a takedown request, moves the Version to takedown pending (`status=5`), and waits for administrator review.

```bash
curl --fail-with-body --silent --show-error \
  -X DELETE \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  -H 'Content-Type: application/json' \
  --data '{"comments":"A critical security issue requires takedown"}' \
  "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions/${VERSION_ID}"
```

**Request body**

| Field | Type | Required | Description |
| --- | --- | :-: | --- |
| `comments` | string | Yes | Reason for the takedown request. |

**Response** `200`:

```json
{"message":"taken down"}
```

This response means the **request was submitted**. It does **not** mean the Version has been taken down. Do not submit it again.

**Errors:** `400` `220201`, `401` `110301`, `403` `110401`, `404` `310501`, `409` `220601`.

---

## 7. Errors

### 7.1 Error format

Failures use `application/problem+json` following **RFC 7807**. Every error contains these stable fields:

| Field | Meaning |
| --- | --- |
| `status` | HTTP status code — transport metadata; always one of the statuses the `code` is registered for. |
| `code` | Stable six-digit, machine-readable business error code. **Branch on this first.** |
| `title` | Short error type. |
| `detail` | Specific reason for this occurrence. |
| `instance` | Request path where the error occurred. |

A Domain error can additionally contain `details` (with `details.advice` as the fix suggestion, and `details.retry_after` on rate-limit errors). A field-validation error can additionally contain `errors`. Neither is present on every error — do not rely on them being there.

**Localization.** The natural-language fields (`title`, `detail`, `details.advice`) are rendered per the request's `Accept-Language` header: any `zh*` variant → Chinese, anything else → English. Different clients will see different wording; never branch on it. Machine fields (`code`, `status`, `details.retry_after`, step field names) never change with language.

Invalid or missing API Token:

```json
{
  "title": "Invalid Token",
  "status": 401,
  "code": 110301,
  "detail": "invalid api token",
  "instance": "/v1/apps"
}
```

Missing Scope:

```json
{
  "title": "Permission Denied",
  "status": 403,
  "code": 110401,
  "detail": "missing scope \"app:read\"",
  "instance": "/v1/apps"
}
```

Version Creation Task missing, inaccessible to the current Developer/App, cancelled, or expired:

```json
{
  "title": "Version Creation Task Not Found",
  "status": 404,
  "code": 310502,
  "detail": "version creation task is not found",
  "instance": "/v1/apps/550e8400-e29b-41d4-a716-446655440000/versions/tasks/550e8400-e29b-41d4-a716-446655440001"
}
```

### 7.2 Error codes

| `code` | HTTP status | Meaning |
| ---: | ---: | --- |
| `100101` | `400` | JSON decoding or request-structure failure |
| `100102` | `413` | Request body exceeds the server's size limit |
| `110301` | `401` | Token missing, invalid, expired, or Developer frozen |
| `110401` | `403` | Token lacks the required Scope |
| `110501` | `404` | API Token not found or deleted |
| `200201` | `400` | Developer input violates a business rule; inspect `title` and `detail` |
| `220201` | `400` | Review input validation failed, such as missing withdrawal comments |
| `220501` | `404` | Review record not found or not owned by the current Developer |
| `220601` | `409` | Current review state does not allow the transition |
| `220701` | `409` | Review operation violates a business rule, e.g. force-takedown of a non-published Version |
| `300201` | `400` | App field validation failed, e.g. missing required field or invalid repo |
| `300501` | `404` | App not found or not owned by the current Developer |
| `300601` | `409` | The App has a reviewing, published, or takedown-pending Version and cannot currently be deleted |
| `300602` | `409` | This App ID is already registered by you on the platform |
| `300603` | `409` | This App ID is already used for another kind |
| `300604` | `409` | This App ID belongs to another Developer and can never be registered again |
| `300801` | `429` | App Release-list rate limit exceeded |
| `300901` | `502`/`503` | App upstream dependency failed |
| `310501` | `404` | Version not found or not related to the specified App |
| `310502` | `404` | Version Creation Task missing, inaccessible, or expired |
| `310601` | `409` | Task state does not allow reading results, cancellation, or confirmation |
| `310801` | `429` | Version Creation Task creation hit the capacity limit |
| `340201` | `400` | Repository URL or host validation failed: not a recognizable `owner/repo` form, or unsupported host |
| `340801` | `429` | Upstream Repo quota exhausted or request rate-limited |
| `340901` | `502`/`503` | Upstream Repo request failed while querying the App Release list |
| `990301` | `503` | Service is shutting down and cannot accept a new task |
| `991001` | `500` | Unexpected internal error |
| `991002` | `500` | Internal failure such as a database error |

Each `code` has a fixed, registered set of HTTP statuses; `200201`, for instance, is always `400` — it is never returned with `409`. A single `code` may still legitimately map to more than one status (see `300901`, `340901`); read both, but branch on `code`.

### 7.3 Error handling rules

Follow this sequence:

1. **Read the integer `code` first.** `code` is the stable business identity; `status` is transport metadata that must be one of the statuses registered for that `code`. **Do not match only on `title` or `detail` text** — they are localized and will differ between clients.
2. Record `code`, `title`, `detail`, and `instance`. Also record `details` or `errors` when present; `details.advice` is the fix suggestion on failures.
3. `401` / `110301` — stop and request a valid Token. Do not retry blindly; a retry loop against an invalid token only burns rate limit.
4. `403` / `110401` — stop and report the missing Scope from `detail`. **Do not probe other resources** to discover what the token can do; `GET /v1/whoami` is the supported way to inspect Scopes.
5. `404` — reload entity IDs from the App or Version list; the ID may be stale or may belong to another resource. For task code `310502`, the task may have been cancelled or expired and must be recreated.
6. `409` — use `code` to distinguish an ordinary business-validation failure from a Task or Review state conflict. Reload resource state before deciding. **Never retry indefinitely.**
7. `429` / `300801` / `340801` — wait for the number of seconds given by `details.retry_after`, then retry the Release-list or upstream-repo request. Never flood the service with concurrent requests.
8. `502` / `340901` — the upstream Repo failed while querying the Release list. Preserve the error and retry a bounded number of times. Package download or parsing failures do **not** return HTTP errors — they show up as failed task steps (see [section 6.4](#64-version-creation)).
9. `503` / `990301` — the service is shutting down. Retry task creation later with the same input.
10. `500` / `991001` — stop automation and report the failure. The response will not expose database, network, credential, or other internal errors.

---

## 8. Complete workflow

The script below creates a version end to end. It requires `curl` and `jq`.

```bash
set -euo pipefail

: "${TDP_BASE_URL:?TDP_BASE_URL is required}"
: "${TDP_API_TOKEN:?TDP_API_TOKEN is required}"
: "${APP_ID:?APP_ID is required}"

TAG='1.0.0'
BROWSER_DOWNLOAD_URL='https://github.com/example/myapp/releases/download/1.0.0/com.example.myapp_x86_64.deb'

TASK_JSON="$({
  jq -n \
    --arg tag "${TAG}" \
    --arg browser_download_url "${BROWSER_DOWNLOAD_URL}" \
    '{tag: $tag, browser_download_url: $browser_download_url}' |
  curl --fail-with-body --silent --show-error \
    -X POST \
    -H "Authorization: Bearer ${TDP_API_TOKEN}" \
    -H 'Content-Type: application/json' \
    --data-binary @- \
    "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions"
})"
TASK_ID="$(printf '%s\n' "${TASK_JSON}" | jq -er '.task_id')"
printf 'Version Creation Task: %s\n' "${TASK_ID}"

while true; do
  STATUS_JSON="$({
    curl --fail-with-body --silent --show-error \
      -H "Authorization: Bearer ${TDP_API_TOKEN}" \
      "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions/tasks/${TASK_ID}"
  })"
  ALL_STATUS="$(printf '%s\n' "${STATUS_JSON}" | jq -er '.all_status')"

  case "${ALL_STATUS}" in
    0|1)
      sleep 2
      ;;
    2)
      break
      ;;
    3)
      printf '%s\n' "${STATUS_JSON}" | jq . >&2
      printf 'Version Creation Task failed; do not confirm it.\n' >&2
      exit 1
      ;;
    *)
      printf 'Unexpected all_status: %s\n' "${ALL_STATUS}" >&2
      exit 1
      ;;
  esac
done

RESULT_JSON="$({
  curl --fail-with-body --silent --show-error \
    -H "Authorization: Bearer ${TDP_API_TOKEN}" \
    "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions/tasks/${TASK_ID}/result"
})"
printf 'Parse Result:\n'
printf '%s\n' "${RESULT_JSON}" | jq .

VERSION_JSON="$({
  curl --fail-with-body --silent --show-error \
    -X POST \
    -H "Authorization: Bearer ${TDP_API_TOKEN}" \
    "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions/tasks/${TASK_ID}/confirm"
})"
VERSION_ID="$(printf '%s\n' "${VERSION_JSON}" | jq -er '.id')"
printf 'Created VERSION_ID=%s\n' "${VERSION_ID}"
printf '%s\n' "${VERSION_JSON}" | jq .
```

If the Parse Result is not what you expected, **do not confirm**. Cancel the task instead:

```bash
curl --fail-with-body --silent --show-error \
  -X POST \
  -H "Authorization: Bearer ${TDP_API_TOKEN}" \
  "${TDP_BASE_URL}/v1/apps/${APP_ID}/versions/tasks/${TASK_ID}/cancel"
```

---

## 9. Standards and conventions

| Aspect | Convention |
| --- | --- |
| Transport | HTTPS |
| Authentication | `Bearer` scheme in the `Authorization` header (RFC 6750) |
| API versioning | Major version in the path prefix (`/v1`) |
| Content type | `application/json` for requests and successes |
| Errors | `application/problem+json`, RFC 7807 |
| Error identification | Six-digit integer `code`; `title` and `detail` are localized human-readable text and may differ between clients |
| Timestamps | **Not unified.** Business objects (App, Version, Release, review timeline) use Unix-seconds integers; token metadata (`GET /v1/whoami` → `token`) uses RFC 3339 strings. See [Time fields](#time-fields). No `updated_at` is exposed. |

### Deliberate deviations from common practice

These are stated explicitly so that nothing is a surprise. Each is a deliberate choice in this API, not an oversight:

- **Most collection endpoints are not paginated.** `GET /v1/apps` and `GET /v1/apps/{app_id}/versions` return the complete list as a bare JSON array — there is no `{items, pagination}` wrapper and no page parameters. The one exception is `GET /v1/apps/{app_id}/releases`, which takes `page` / `per_page` and is strictly rate-limited.
- **Enumerations are integers,** not strings. See [Version status](#42-version-status).
- **Timestamps come in two flavors.** Unix seconds on business objects, RFC 3339 strings on token metadata. This is deliberate; see [Time fields](#time-fields).
- **`kind` has two notations.** `.deb` / `docker image` (display form) in the App-list response; `deb` / `docker` everywhere else. See [section 6.2](#62-apps).
- **UUIDs in paths, business IDs in bodies.** `{app_id}` in a path is always the entity UUID; the human-readable business identifier travels as the `app_id` body field. The two are never interchangeable.
- **`DELETE` on a version is not a delete.** It creates a takedown request. See [section 6.5](#65-version-disposal).
- **There is no idempotency key.** Confirmation is idempotent by `task_id`, and re-submitting the current repo URL is idempotent; for everything else, avoid blind retries and re-read state first.

---

## 10. Resources

| Resource | Description |
| --- | --- |
| API Keys page | Issue and delete API Tokens on the Developer Platform web portal. |
| Accept-Language | Controls the language of human-readable response text. See [section 2.2](#22-request-headers). |

This document is the complete interface specification for the Agent API.
