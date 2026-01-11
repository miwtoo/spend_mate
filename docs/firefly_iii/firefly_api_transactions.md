# Firefly III API — Transactions (Read + Create)

Sources:

- Interactive API docs (choose your version): `https://api-docs.firefly-iii.org/`
- API reference landing: `https://docs.firefly-iii.org/references/firefly-iii/api/`

## Key ideas / vocabulary

- Firefly internally uses **transaction journals / splits**. Many “transaction” operations ultimately work with journals.
- For day-to-day app usage, you’ll most often:
  - list/search transactions
  - create a new transaction (withdrawal/deposit/transfer)

## Useful endpoints you’ll see in the docs

Exact routes/params vary slightly by version; confirm in the interactive docs.

### List transactions for an account

- `GET /api/v1/accounts/{id}/transactions`

Use when you already know the account ID and want scoped transactions.

### Transaction journals (advanced / internal)

- `GET /api/v1/transaction-journals/{id}`
- `DELETE /api/v1/transaction-journals/{id}`
- `GET /api/v1/transaction-journals/{id}/links`

These are helpful when:

- you need to inspect or manage a specific split/journal
- you’re dealing with links between transactions

## Minimal curl patterns

### Example: list account transactions

```bash
curl -X GET "https://<host>/api/v1/accounts/<ACCOUNT_ID>/transactions?page=1" \
  -H "accept: application/vnd.api+json" \
  -H "Authorization: Bearer <TOKEN>"
```

## What we typically need in SpendMate

For “get transactions”, the app usually needs:

- amount + currency
- description
- date
- source/destination account IDs + names
- type (withdrawal/deposit/transfer)

When implementing, we’ll map the API’s JSON fields into a Dart model used by repositories/view-models.

## Error handling notes

- The All Transactions screen hits `GET /api/v1/transactions` with `start/end/page` query params.
- If Firefly/Cloudflare returns HTML (5xx or non-JSON), treat it as an API error, log a short response snippet, and show a friendly retry message (never surface raw HTML).

## Authentication handling

All API requests must include:
- `Authorization: Bearer <TOKEN>` header with the Firefly III personal access token
- `Accept: application/vnd.api+json` header to request JSON API responses

When authentication fails (invalid/expired token), Firefly III returns HTTP 302/301 redirects to an HTML login page. The app detects these redirects and:

1. Logs the redirect status and location header for debugging (without exposing tokens)
2. Throws a `FireflyApiException` with status code 401 and user-friendly message
3. Shows the user "Authentication failed. Please check your Firefly III API token."

Error logging format:
```
Firefly API error <METHOD> <URI> status=<STATUS> content-type=<CONTENT-TYPE> snippet="<SNIPPET>"
```

The snippet is truncated to 200 characters and HTML is sanitized from user-facing messages.

