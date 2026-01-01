# Firefly III API — Pagination & List Endpoints

Sources:

- `https://api-docs.firefly-iii.org/`
- `https://docs.firefly-iii.org/references/firefly-iii/api/`

## What to expect for “list” endpoints

Most “list” endpoints return a **paged** response (you’ll see pagination info in the response payload).

Typical patterns you’ll see in the interactive docs:

- query params like `page` (sometimes also `limit` / `per_page` depending on endpoint/version)
- response includes `data: [...]` plus metadata/links for pagination

## Recommended client behavior

- Start with `page=1`
- Keep requesting subsequent pages until:
  - the returned `data` list is empty, or
  - pagination metadata indicates you reached the last page

## Filtering & sorting (endpoint-specific)

Filtering options vary per endpoint (transactions have the richest filters). Always check the interactive docs for:

- date range params (often `start` / `end`)
- type filters (withdrawal/deposit/transfer)
- account or category scoping routes (e.g. “transactions for a given account”)

## Notes for this project

When we implement Firefly API calls in Flutter, we should:

- centralize pagination handling in one helper
- return a typed list + “next page” cursor in repositories


