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


