# Finance Design Contract â€” Phase 0.5

Source of truth: `docs/reference/finance/Cafe618_Finance_Workspace_CORRECTED.html` (SHA-256 `71DE559020DB49BF1BBEEB65D874FE9F2CF86CBF727BFF480FFD0378A31CDBDB`). This document records only values present in that reference; it is not a new visual interpretation.

## Shell and layout

| Token | Exact reference value | Required Finance use |
|---|---|---|
| Outer canvas | `#EDE7DE` | Window/background around the workspace. |
| Application surface | `#FAF7F2` | Main shell and content background. |
| Shell frame | `1440px` wide, `900px` high, `28px auto` margin, `16px` radius | Desktop reference viewport. |
| Shell border/shadow | `1px solid #E7E2DA`; `0 20px 50px rgba(59,36,23,.18)` | Main workspace container. |
| Sidebar | `236px`; `#F0EDED`; `28px 16px` padding | Shared Finance navigation rail. |
| Top bar | `60px`; horizontal padding `28px`; `#FAF7F2`; bottom border `#E7E2DA` | Shared Finance top chrome. |
| Content | `22px 32px 28px` padding; `16px` section gap | Every canonical Finance route. |
| Card/table surface | `#FFFFFF`, `1px solid #E7E2DA`, `12px` radius | Context, entity, KPI, table, and workflow cards. |
| Card padding | Context `12px 16px`; entity/info `16px 18px` | Do not introduce route-specific alternatives. |

## Type, colour, controls

| Token | Exact reference value |
|---|---|
| Font | `IBM Plex Sans Arabic` at weights `400, 500, 600, 700, 800` |
| Main text | `#231005` |
| Supporting text | `#6B6B6B` |
| Muted text | `#8B8B8B` |
| Primary action / strong icon | `#3B2417` |
| Link/accent | `#6B4226` |
| Brand accent | `#C47A3A` |
| Border/soft separator | `#E7E2DA` / `#F0EDED` |
| Success | foreground `#2E7D32`, background `#E3F5E8`, border `#BFE5C8` |
| Warning | background `#FCEFDD` or `#F4E7D3`, foreground `#805437` |
| Error | `#C62828` |
| Page title | `22px`, weight `700`, `#231005` |
| Entity title | `19px`, weight `700`, `#231005` |
| Body/table text | `12.5px`â€“`13.5px`; key values `600`/`700` |
| Primary button | `36px` high, `8px` radius, `#3B2417` fill, white text, `12.5px`/700 |
| Compact input/button | `34px` high, `8px` radius, `#FAF7F2`, `1px #E7E2DA` |
| Status chip | `999px` radius; small text `11px`/700 |

## Required composition

1. Every canonical Finance route uses the same sidebar, top bar, page heading, Finance tab strip, and global context block when the reference enables it.
2. Global context contains period presets, branch selector, and prior-period compare switch; it stays stable while navigating Finance routes.
3. Detail pages use the reference drill breadcrumb and entity header before the content card/table.
4. Tables keep the shared filter row, surface/border/radius, status chips, empty/loading/error states, and previous/next pagination. Server data is requested at 10 rows per page for the Finance operational lists.
5. Workflow warnings, readiness, and completed states use the success/warning/error tokens above, not screen-specific colours.

## Acceptance method

Phase 1 visual work must compare a representative desktop screenshot for every canonical route against the checked-in reference at the 1440px shell size. Any intentional exception must be recorded in `FINANCE_UI_GAPS.md` with the reason and target phase.
