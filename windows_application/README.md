# Cafe System 618 Windows Application

## Published Version History

The Review workflow includes a Versions tab scoped only by Branch and Sales
Channel. History is paginated and metadata-only; details show bounded Snapshot
counts, while immutable JSON is fetched only as an explicit read-only LTR
diagnostic. Backend comparison output is bounded and `truncated` is explicitly
non-exhaustive. Rollback creates a new immutable Version and never reactivates a
historical Version; no-change rollback refreshes History and Current Version.
POS Snapshot Sync remains unimplemented and broader localization migration is
still paused.

Menus and Sections are administered through `/menu-management/menus`, `/create`,
`/:menuId`, `/:menuId/edit`, and `/:menuId/placements`. A Catalog Product belongs
to the Catalog; a Product Placement belongs to one Menu Section. Placements support
server-side product search, display overrides, visible/hidden state, move, ordered
reorder, and soft archive/restore. A Product may be placed in different Sections but
not twice in the same active Section; moves are limited to eligible Sections in that
same Menu. Archived Menus and Sections are read-only.
Hidden and archived placements are different states; Product lifecycle is shown
separately. Branch/Channel assignments and schedules are administered through
`/menu-management/assignments`. The screen uses tenant-scoped active Branches and
the backend SalesChannel values, supports complete-scope ordering and assignment
activation, and never exposes Tenant IDs. Removing an assignment leaves the Menu,
Sections, Placements, and published history untouched.

Menu schedules are Menu-owned rules scoped to the selected Branch and Channel.
No scoped active rules means the Menu is unrestricted. Weekly days (`0`–`6`), date
ranges, priorities, active state, and overnight windows such as `22:00–02:00` are
supported. The branch timezone is displayed as context; the desktop client does not
evaluate current availability in its machine timezone. Rule synchronization follows
the backend's complete-set contract: omission removes that editable rule and there is
no independent rule restore action. The client first loads every rule for the Menu,
then preserves global and other Branch/Channel scopes while editing only the selected
exact scope; inherited rules are diagnostics, not copied or editable there. Preview, Validation, Publishing, Version History,
Variant Price Overrides are available at `/menu-management/products/:productId/variants/:variantId/pricing`. Variant Base Price remains owned by Variant Management; this diagnostic/administration screen manages only Branch, Channel, and Branch + Channel overrides. The complete-sync endpoint is loaded authoritatively before edits, submits the complete draft set, preserves untouched scopes, and reloads after success. Effective Price is resolved by the backend using Branch + Channel → Branch → Channel → Variant Base Price. Archived Products and Variants remain diagnostic/read-only. Scheduled Product and Variant Availability is Phase 4D.2; POS Sync remains a later phase.

Product archive and restore are available from Product Catalog actions and Product Detail. Archive is a soft-delete lifecycle operation: it does not permanently delete the Product, change existing Orders, or modify published historical snapshots. Restore returns the Product to the editable Catalog but does not publish it, assign it to a Menu, restore archived Variants/Modifier data, or make it operationally available. `isActive` and archived state are distinct; archived status is identified by `archivedAt`.

Product Modifier Assignment is available at `/menu-management/products/:productId/modifiers`. It manages only product-to-library assignment: shared Groups and Options remain owned by Modifier Library. The screen distinguishes Library Defaults, nullable Product Overrides, and resolved Effective Settings. Removing an assignment never deletes a Group or Option; Menu Builder, Availability, and publishing remain later phases.

The Flutter Windows desktop application supports POS, Orders, Discounts, Reports, and the read-only Menu Management Product Catalog. Menu Management uses the real Laravel Admin Catalog APIs; it contains no mock menu data.

Menu Management has an integrated Review & Preview & Publish workflow at `/menu-management/review`. It selects a tenant Branch and actual Sales Channel, then reviews either one assigned Menu or the complete assigned collection. Validation is authoritative: errors block, while warnings and information remain diagnostic and warnings can proceed only after explicit confirmation. Publishing calls `POST /api/v1/admin/menu-management/publish`; a selected Menu sends its supported `menuIds` value and collection scope omits `menuIds` so Backend resolves active assignments. Backend reruns validation, creates an immutable Version only when semantic content changes, and records a no-change publication without creating a Version when it does not. Existing Orders are never modified. `GET /api/v1/admin/menu-management/current-version` displays metadata only, never the Snapshot payload. Operational sold-out, temporary overrides, and remaining quantities are excluded from immutable Snapshots. Phase 4F Version History, comparison, rollback, and POS Sync remain unimplemented.

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Backend tax rates are supplied with each branch and stored on backend orders/receipts. The shared Flutter tax configuration is only a fallback for local/mock data or malformed responses.

## Localization

The desktop application supports English (`en`) and Arabic (`ar`) through Flutter
`gen_l10n`. Translation sources are `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb`;
run `flutter gen-l10n` after changing them. The top-bar language selector changes
the UI immediately and persists its choice under `app_locale`; a missing preference
uses a supported operating-system locale and otherwise falls back to English.

Arabic uses RTL layout. New shared UI must use directional layout primitives, retain
technical values such as SKU and API codes as focused LTR islands, and format dates,
numbers, and branch currency using the active display locale without changing API
numeric serialization. See `../docs/FLUTTER_LOCALIZATION_ARCHITECTURE.md` for the
entity-field fallback and enum/reason-code presentation rules. Menu Management is
paused after the new Phase 4E.3 publishing strings; no full screen-by-screen
translation migration was added. Checksum, Version number, Publication ID, and
diagnostic timestamps remain LTR in Arabic.

Menu Management includes the central Modifier Library routes: `/menu-management/modifiers`, `/create`, `/:modifierGroupId`, and `/:modifierGroupId/edit`. It manages reusable Modifier Groups and their Options, including archive/restore and active-option ordering. Price Delta belongs to an Option; Variant Base Price belongs to its Variant. Product Modifier Assignment is implemented separately at the Product route. POS continues to use the temporary Catalog API.

## Scheduled Product and Variant Availability

Phase 4D.2 is administered at `/menu-management/products/:productId/availability`, with optional `variantId`, `branchId`, and `channel` query parameters. The backend owns one complete Product rule set: a null `productVariantId` identifies a Product rule and a Variant ID identifies a Variant rule. Each rule has one nullable `dayOfWeek` (`0`–`6`), not a multi-day `daysOfWeek` array. Flutter loads and saves the full authoritative set, preserving scopes not being edited. The backend preview is authoritative and evaluates in the selected Branch timezone: Variant rules take precedence over Product rules, followed by Branch + Channel, Branch, Channel, and Global. No governing rule is unrestricted; a governing scope outside every window is `outside_schedule`; overnight rules are supported. Operational overrides remain a separate runtime feature.

## Operational Availability Overrides

Phase 4D.3A is administered at `/menu-management/products/:productId/operational-availability`, with optional `variantId`, `branchId`, and `channel` query parameters. It manages immediate Product and Variant runtime override records only, through the real Product and Variant operational-availability endpoints. A record always has an active Tenant Branch plus either an actual Sales Channel or `all` for every channel in that Branch; branchless global records are not part of this API.

`available`, `sold_out`, and `temporarily_unavailable` are stored override statuses. An explicit narrower Available record may override a broader Sold Out record without deleting it. Temporary records use `unavailableUntil`, interpreted by the backend in the selected Branch timezone; expired records remain stored and visible diagnostically but the resolver ignores them. Remaining quantity is operational metadata only and is never synchronized to Inventory or used to automatically change status. Operational overrides are separate from Scheduled Availability and are excluded from immutable Published Snapshots. Product archival makes all override mutations read-only; Variant archival makes only that Variant's overrides read-only.

Phase 4D.3B adds the authoritative Operational Resolution section to that same screen. It calls `GET /api/v1/admin/catalog/products/{product}/operational-availability-preview` with an active Branch and a real runtime Sales Channel; Variant context uses `productVariantId` on that endpoint. The Backend response, not Flutter, resolves Variant exact Channel → Variant `all` → Product exact Channel → Product `all` → Available fallback. The diagnostic distinguishes an explicit Available match from the `no_operational_override` fallback, shows the matched level/scope/record, and leaves expired records visible in the override list while reporting the next active backend match. `all` is only an override scope, never a requested runtime channel. Operational resolution is not a complete sellability result and remains separate from scheduled rules, publishing, inventory, and immutable snapshots.
