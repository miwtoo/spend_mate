# Firefly III API — Accounts (Lookup for Transactions)

Sources:

- Interactive API docs: `https://api-docs.firefly-iii.org/`
- API reference landing: `https://docs.firefly-iii.org/references/firefly-iii/api/`

## Why accounts matter

Most transaction flows require account IDs:

- **withdrawal**: source = asset account, destination = expense account (often)
- **deposit**: source = revenue account, destination = asset account
- **transfer**: asset → asset (or similar)

So, we usually need to:

- list accounts by type
- let the user pick from them
- map names to IDs for transaction creation

## Useful endpoints/patterns

### List accounts

The interactive docs include endpoints to list accounts and filter by type.

### List transactions for a given account

- `GET /api/v1/accounts/{id}/transactions`

This is the most common “show me this account’s activity” call.

## Minimal curl patterns

### Example: list account transactions

```bash
curl -X GET "https://<host>/api/v1/accounts/<ACCOUNT_ID>/transactions?page=1" \
  -H "accept: application/vnd.api+json" \
  -H "Authorization: Bearer <TOKEN>"
```


