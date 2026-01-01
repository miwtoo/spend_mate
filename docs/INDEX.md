# Docs index

## Firefly III API reference notes

Entry point:

- `docs/firefly_iii/INDEX.md`

# Firefly III API — Local Reference Index

This folder is a **local, curated reference** for the Firefly III API, based on:

- Interactive API docs: `https://api-docs.firefly-iii.org/`
- Reference docs: `https://docs.firefly-iii.org/references/firefly-iii/api/`
- “How to use the API”: `https://docs.firefly-iii.org/how-to/firefly-iii/features/api/`

## Quick links

- **Auth & headers**: [`firefly_api_auth.md`](./firefly_api_auth.md)
- **Pagination & list endpoints**: [`firefly_api_pagination.md`](./firefly_api_pagination.md)
- **Transactions (read + create)**: [`firefly_api_transactions.md`](./firefly_api_transactions.md)
- **Accounts (lookup for transactions)**: [`firefly_api_accounts.md`](./firefly_api_accounts.md)

## Conventions used in these notes

- **Base URL**: `https://<your-firefly-host>`
- **API base path**: `/api`
- **API version**: usually `/v1` (see the API docs selector for your instance version).

## How to use these docs with me (the AI)

When you ask something like “get transactions”, tell me:

- the file to use, e.g. “Use `docs/firefly_api_transactions.md`”
- your Firefly base URL (or say “use FIREBASE_URL env var” if you store it)
- whether you’re using **OAuth2** or **Personal Access Token**


