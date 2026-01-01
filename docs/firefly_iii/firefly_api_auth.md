# Firefly III API — Auth & Headers

Sources:

- `https://docs.firefly-iii.org/how-to/firefly-iii/features/api/`
- `https://api-docs.firefly-iii.org/`

## Base URL & versioning

- Requests are made to your own Firefly III instance, e.g. `https://firefly.example.com`.
- Endpoints are versioned (most commonly **v1**), e.g. `GET /api/v1/...`.
- Use the interactive docs selector (`api-docs.firefly-iii.org`) to match your running Firefly III version.

## Authentication options

Firefly III supports:

- **OAuth2** (recommended for third-party apps)
- **Personal Access Tokens** (simpler for scripts / trusted clients)

## Personal Access Token (common for local dev)

Use an `Authorization` header with a Bearer token:

```bash
curl -X GET "https://<host>/api/v1/about" \
  -H "accept: application/vnd.api+json" \
  -H "Authorization: Bearer <PERSONAL_ACCESS_TOKEN>"
```

## Common headers

- `Authorization: Bearer <token>`
- `accept: application/vnd.api+json`
- `Content-Type: application/json` (for POST/PUT/PATCH bodies)

## Practical tips

- **Verify connectivity**: start with `GET /api/v1/about` (or any small endpoint shown in the interactive docs).
- **Token scope**: if you get 401/403, regenerate token and ensure it’s for the correct user / instance.


