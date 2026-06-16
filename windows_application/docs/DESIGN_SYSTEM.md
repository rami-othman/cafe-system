# Design System

Cafe System 618 uses a desktop-first design system based on a warm artisan cafe
palette. The goal is a calm, readable POS foundation with warm brown actions,
soft surfaces, clear hierarchy, and enough density for Windows desktop use.

## Colors

Core palette:

| Token | Value | Use |
| --- | --- | --- |
| `primary` | `#3B2417` | Main actions, active navigation, strong brand surfaces |
| `secondary` | `#6B4226` | Secondary actions and supporting brown accents |
| `tertiary` | `#C47A3A` | Highlights, warnings, small emphasis moments |
| `neutral` | `#1F1F1F` | Dark neutral text and inverted controls |

Surface and border tokens:

| Token | Value | Use |
| --- | --- | --- |
| `background` | `#FAF7F2` | App shell background |
| `surface` | `#FFFFFF` | Cards, panels, inputs, dialogs |
| `surfaceAlt` | `#F0EDED` | Sidebar and alternate panel backgrounds |
| `border` | `#E7E2DA` | Control, card, and shell borders |
| `divider` | `#E7E2DA` | Fine separators |
| `contentBackground` | `#FCF9F8` | Main content canvas |
| `navActiveBackground` | `#FEC29E` | Active sidebar item |
| `navActiveText` | `#794E31` | Active sidebar item text and icon |

Text and status tokens:

| Token | Value |
| --- | --- |
| `textPrimary` | `#231005` |
| `textSecondary` | `#50443F` |
| `textMuted` | `#6B6B6B` |
| `textInverse` | `#FFFFFF` |
| `success` | `#2E7D32` |
| `warning` | `#C47A3A` |
| `danger` | `#C62828` |
| `info` | `#1565C0` |

## Typography

Current font family: `Manrope`.

The theme registers `Manrope` through `pubspec.yaml` and expects this font file:

```txt
assets/fonts/Manrope-VariableFont_wght.ttf
```

Typography tokens live in `lib/core/theme/app_text_styles.dart`:

- `displayLarge`
- `displayMedium`
- `headlineLarge`
- `headlineMedium`
- `titleLarge`
- `titleMedium`
- `bodyLarge`
- `bodyMedium`
- `bodySmall`
- `labelLarge`
- `labelMedium`
- `labelSmall`
- `buttonLarge`
- `buttonMedium`

The scale is intended for desktop POS readability: clear labels, strong section
titles, and body text large enough for repeated use during service.

## Spacing

Spacing tokens live in `lib/core/theme/app_spacing.dart`.

| Token | Value |
| --- | ---: |
| `xs` | `4` |
| `sm` | `8` |
| `md` | `12` |
| `lg` | `16` |
| `xl` | `24` |
| `xxl` | `32` |
| `xxxl` | `48` |

Reusable `EdgeInsets` helpers are available for common all-side, horizontal,
and vertical spacing.

## Radius

Radius tokens live in `lib/core/theme/app_radius.dart`.

| Token | Value |
| --- | ---: |
| `sm` | `8` |
| `md` | `12` |
| `lg` | `16` |
| `xl` | `20` |
| `xxl` | `28` |
| `pill` | `999` |

Shared border radius helpers include `control`, `card`, `panel`, and
`pillRadius`.

## Buttons

`AppButton` lives in `lib/shared/widgets/app_button.dart`.

Supported variants:

- `primary`
- `secondary`
- `outlined`
- `inverted`
- `danger`

Buttons use centralized height, typography, radius, and warm cafe colors.

## Cards

`AppCard` lives in `lib/shared/widgets/app_card.dart`.

It supports:

- `child`
- `padding`
- `margin`
- `borderRadius`
- `onTap`

Cards use the shared surface color, border token, and rounded radius. They
should be used for panels, repeated items, and framed tools.

## Inputs

`AppTextField` lives in `lib/shared/widgets/app_text_field.dart`.

It supports:

- `label`
- `hint`
- `prefixIcon`
- `suffixIcon`
- `controller`
- `onChanged`
- `keyboardType`
- `enabled`

Inputs use the shared input height, surface color, border token, and focused
secondary brown outline.

## Desktop Layout

Desktop sizing tokens live in `lib/core/constants/app_sizes.dart`.

Important tokens include:

- `sidebarWidth`
- `topBarHeight`
- `rightPanelWidth`
- `cartPanelWidth`
- `minDesktopWidth`
- `minDesktopHeight`
- `productCardMinWidth`
- `productCardHeight`
- `buttonHeight`
- `inputHeight`
- `iconButtonSize`

The layout direction is Windows desktop first. Tablet support may be added
later, but the primary density and sizing should fit desktop POS workflows.

Shell dimensions:

| Token | Value |
| --- | ---: |
| `sidebarWidth` | `240` |
| `sidebarRailWidth` | `72` |
| `topBarHeight` | `72` |
| `rightPanelWidth` | `380` |
| `mediumRightPanelWidth` | `352` |

Responsive breakpoints:

| Token | Value |
| --- | ---: |
| `compactBreakpoint` | `900` |
| `mediumBreakpoint` | `1200` |
| `largeBreakpoint` | `1366` |

At `1200px` and wider, the shell uses the expanded sidebar and full inline
cart panel. From `900px` to `1199px`, the sidebar collapses to the rail and the
cart panel stays inline at the medium width. Below `900px`, the sidebar remains
a rail, the inline cart panel is hidden, and the topbar exposes a cart icon
placeholder for the future drawer/sheet interaction.

Minimum Windows size enforcement is not configured yet. `AppSizes` records a
target usable size of `1024 x 700`; adding `window_manager` remains a later
app-bootstrap task.

## Sidebar

The global sidebar uses `AppSidebar` and `AppSidebarItem`.

- Background: `surfaceAlt`
- Right border: `border`
- Item height: `44`
- Item radius: `AppRadius.sm`
- Active background: `navActiveBackground`
- Active text/icon: `navActiveText`
- Inactive text/icon: `textSecondary`

The current active item is `POS`.

## Topbar

The global topbar uses `AppTopBar`.

- Height: `topBarHeight`
- Background: `background`
- Bottom border: `border`
- Horizontal padding: `AppSpacing.xl`
- Active branch text and underline: `textPrimary`
- Inactive branch text: `textSecondary`
- Shift status uses `ShiftStatusBadge` with a green status dot.

## Feature Components

Feature-specific components should stay inside their owning feature unless they
are reusable across multiple features. Shared reusable primitives belong in
`lib/shared`.

## POS Product Area

The POS product area renders inside the app shell content slot.

- Background: `contentBackground`
- Padding: `AppSpacing.xl`
- Search width: `AppSizes.posSearchWidth`
- Search height: `AppSizes.posSearchHeight`
- Search surface: `surface`
- Search border: `border`
- Search radius: `AppRadius.sm`
- Section gap: `AppSpacing.xl`

Category tabs:

- Height: `AppSizes.categoryTabHeight`
- Gap: `AppSpacing.sm`
- Active background: `primary`
- Active text: `textInverse`
- Inactive background: `surface`
- Inactive border: `border`
- Inactive text: `textDark`
- Label style: Manrope semibold, 12px, uppercase, `0.6` letter spacing

## POS Product Cards

Product cards are feature-specific widgets in `lib/features/pos/widgets`.

- Background: `surface`
- Border: `border`
- Radius: `AppRadius.md`
- Grid gap: `AppSizes.productGridGap`
- Minimum card width: `AppSizes.productCardMinWidth`
- Card height: `AppSizes.productCardHeight`
- Visual area height: `AppSizes.productCardImageHeight`
- Product name: `primary`, bold, 14px
- Size text: `textMuted`, semibold, 12px
- Price text: `tertiary`, semibold, 18px

Unavailable products use reduced opacity, a warm overlay, and a pill label.

## POS Cart Panel

The POS cart panel renders inside the app shell right panel slot.

- Width comes from `AppSizes.rightPanelWidth`
- Medium inline width comes from `AppSizes.mediumRightPanelWidth`
- Hidden inline below `AppSizes.compactBreakpoint`; the topbar shows a cart
  icon placeholder instead
- Background: `white`
- Left border: `shellBorder`
- Header controls padding: `AppSpacing.md`
- Cart item list padding: `AppSpacing.lg`
- Footer background: `shellBackground`
- Footer top border: `shellBorder`

## Order Type Selector

- Container background: `surfaceAlt`
- Radius: `AppRadius.sm`
- Padding: `AppSpacing.xs`
- Active segment background: `surface`
- Active text: `primary`
- Inactive text: `textSecondary`
- Label style: Manrope semibold, 12px, uppercase, `0.6` letter spacing

## Quantity Stepper

- Container background: `surfaceAlt`
- Container radius: `AppRadius.sm`
- Minus/plus button size: `AppSizes.quantityButtonSize`
- Minus/plus button background: `surface`
- Quantity text: `textDark`, semibold

## POS Action Buttons

Secondary actions:

- Labels: `HOLD`, `CANCEL`, `PRINT`
- Height: `AppSizes.cartControlHeight`
- Background: `surface`
- Border: `border`
- Radius: `AppRadius.sm`
- Label style: Manrope bold, 12px, uppercase, `0.6` letter spacing
- Cancel color: `dangerStrong`

Pay button:

- Label: `PAY $15.66`
- Height: `AppSizes.payButtonHeight`
- Background: `tertiary`
- Text: `textInverse`
- Radius: `AppRadius.sm`
- Label style: Manrope semibold, 18px, uppercase, `0.45` letter spacing

## POS Customization Modal

The product customization dialog is a desktop-first modal used before adding a
configured POS item to the cart.

- Backdrop: black at roughly 40% opacity with subtle blur
- Width: `AppSizes.customizationDialogWidth`
- Max height: `AppSizes.customizationDialogMaxHeight`
- Radius: `AppRadius.md`
- Header height: `AppSizes.customizationDialogHeaderHeight`
- Header background: `primarySoft`
- Header title: Manrope semibold, 24px, `primary`
- Left product column: `surfaceAlt`, 320px on desktop, right border
- Right modifier column: `white`, scrollable, `AppSpacing.xl` padding
- Footer: fixed bottom, `white`, top border `border`

Modifier option styling:

- Option height: `AppSizes.customizationOptionHeight`
- Radius: `AppRadius.sm`
- Unselected background: `surface`
- Unselected border: `border`
- Selected background: `primarySoft`
- Selected border: `tertiary`
- Card-style option groups use `white`, `border`, `AppRadius.sm`, and a soft
  low-opacity shadow

Segmented selectors:

- Container background: `surfaceAlt`
- Border: `border`
- Radius: `AppRadius.sm`
- Selected segment background: `white`
- Selected segment shadow: subtle 1px vertical lift

Footer actions:

- Cancel: text button, `primary`
- Add to Order: filled `tertiary`, `white` text, `AppRadius.sm`,
  `AppSizes.buttonHeight`, optional cart icon

## POS Discount Modal

The POS discount dialog is a centered, desktop-first modal for local coupon and
available-discount application.

- Backdrop: black at roughly 40% opacity
- Width: `AppSizes.discountDialogWidth`
- Max height: `AppSizes.discountDialogMaxHeight`
- Radius: `AppRadius.md`
- Surface: `white`
- Header height: `AppSizes.discountDialogHeaderHeight`
- Header background: `white`
- Header bottom border: `border`
- Header title: Manrope semibold/bold, 24px, `primary`
- Body padding: `AppSpacing.xl`
- Footer background: `shellBackground`
- Footer top border: `border`

Coupon input styling:

- Label: uppercase Manrope bold, 12px, `textSecondary`
- Input height: `AppSizes.inputHeight`
- Input background: `white`
- Input border: `border`
- Input radius: `AppRadius.sm`
- Apply button width: `AppSizes.discountInputApplyWidth`
- Apply button background: `tertiary`, text `white`
- Validation messages use `dangerStrong`, 12px text, and a small warning icon

Discount card styling:

- Background: `white`
- Border: `border`
- Radius: `AppRadius.sm`
- Minimum height: `AppSizes.discountCardMinHeight`
- Padding: `AppSpacing.md`
- Leading icon container: `AppSizes.discountIconContainerSize`,
  `discountIconBackground`, pill radius
- Title: Manrope bold, 14px, `textPrimary`
- Subtitle: Manrope medium, 12px, `textMuted`
- Apply action: Manrope bold, 12px, `secondary`

Discount badge styling:

- Morning Rush: `discountOrangeBadge` background, `discountOrangeText` text
- VIP Reward: `discountBlueBadge` background, `discountBlueText` text
- Pastry Special: `discountGreenBadge` background, `discountGreenText` text
- Badge radius: `AppRadius.pillRadius`

Applied discount total row:

- Appears between Subtotal and Tax
- Label: `Discount`
- Value: negative currency amount
- Text color: `dangerStrong`
- Remove action: compact text action in `secondary`
