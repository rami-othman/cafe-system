repo: rami-othman/cafe-system
branch: main
path: windows_application

## Last sync
date: 2026-08-19T08:52:38Z

### Updated in this project
- Built 7 Arabic RTL screens for a new Inventory module, grounded in the real Flutter app's design tokens (AppColors/AppRadius/AppSpacing/AppTextStyles) and shared shell widgets (AppSidebar, AppTopBar, ShiftStatusBadge, AppCard, AppButton, DiscountsTable pattern).
- Sidebar, top bar, branch tabs, shift badge, buttons, cards, table header/row/pagination recreated to match `windows_application/lib/shared/widgets/*` exactly (colors, radii, spacing).
- No inventory screens existed yet in the repo (Phase 1 foundation) — this is new UI built on the existing theme, not a replacement of existing screens.

## Screen map
| Project screen | Repo files |
| --- | --- |
| Shell (sidebar/topbar/shift badge) | lib/shared/widgets/app_sidebar.dart, app_sidebar_item.dart, app_top_bar.dart, shift_status_badge.dart |
| Colors/type/radius/spacing tokens | lib/core/theme/app_colors.dart, app_text_styles.dart, app_radius.dart, app_spacing.dart, app_theme.dart |
| Cards/buttons/breadcrumbs/empty state | lib/shared/widgets/app_card.dart, app_button.dart, app_breadcrumbs.dart, app_empty_state.dart |
| Table/badges/search pattern reference | lib/features/discounts/widgets/discounts_table.dart, discount_status_badge.dart, discount_search_controls.dart |