# Deployment Phase 1C — Flutter Web Compatibility

The operational Flutter application is one project targeting Windows and Web.
Its router retains path-based `go_router` locations; no hash URL strategy was
introduced. A future static host must provide its SPA fallback separately.

| Feature | Windows | Web |
| --- | --- | --- |
| Opaque Laravel bearer auth | Windows secure storage | Browser local storage for staging; XSS-exposed |
| Cross-tab auth changes | N/A | Browser `storage` event restores/invalidates session |
| POS browsing and cart preparation | Supported | Supported |
| Offline POS menu cache | File cache, tenant + branch + channel scoped | IndexedDB, same scope |
| Product image selection/upload | File picker and native drag/drop, bytes multipart | Browser file picker, bytes multipart |
| Menu Management | Supported | Supported |
| Printing | Preview only | Preview only; no native printing SDK |

## Security and operational notes

- Web staging persists the opaque bearer token plus session metadata in browser
  storage so a session survives refresh. This is intentionally **not** equivalent
  to Windows secure storage: script executing under the origin can read it.
  Production hardening should evaluate an HttpOnly-cookie/BFF browser model.
- The existing twelve-hour offline authenticated-session maximum is unchanged.
  Payments, refunds, backend mutations, and mutation queues remain unavailable
  while offline.
- Product images are uploaded first using bytes, filename, and MIME type. For
  an existing Product, the backend atomically updates the URL after the new
  upload and only then performs best-effort cleanup of the previous object.
  A create-flow upload is necessarily unreferenced until the subsequent Product
  create succeeds; the client does not retry either mutation automatically.
- `API_BASE_URL` remains a public `--dart-define` only. Never place database,
  Laravel, Supabase, or storage credentials in Flutter configuration.

## Local Web verification

```sh
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8085/api/v1
```

The Laravel CORS allow-list must include the browser origin used for local Web
testing (for example `http://localhost:<port>`). Do not add a future Netlify
origin until deployment configuration work.
