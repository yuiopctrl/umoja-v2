# Design System

This document describes Umoja's visual foundation, introduced in
Prompt 05 and given a branding/typography/localization polish pass in
Prompt 05A: design tokens, the Material 3 theme built from them, the
responsive application shell, the reusable component library, official
brand assets, the Ubuntu UI typeface, and Kiswahili status/role
localization. Members Management (Prompt 04) was redesigned on top of
this foundation and is the reference implementation for how a module
should look and behave. **Every future module (Contributions, Payments,
Wallet, Hisa, Loans, Financial Accounts, Reports) must reuse this
design system and app shell — none of them should introduce a
parallel/unrelated visual system, color palette, spacing scale,
navigation pattern, typeface, or brand treatment.**

## Source layout

```
app/lib/core/theme/     design tokens + ThemeData
  umoja_colors.dart
  umoja_spacing.dart
  umoja_radius.dart
  umoja_typography.dart
  umoja_breakpoints.dart
  umoja_theme.dart

app/lib/core/branding/  official brand artwork
  umoja_brand_mark.dart

app/lib/core/widgets/   reusable component library
  umoja_page.dart, umoja_page_header.dart, umoja_section.dart,
  umoja_card.dart, umoja_list_tile.dart, umoja_status_badge.dart,
  umoja_empty_state.dart, umoja_error_state.dart, umoja_loading_state.dart,
  umoja_search_field.dart, umoja_buttons.dart, umoja_form_section.dart,
  umoja_responsive_content.dart, umoja_confirmation_sheet.dart,
  umoja_initials_avatar.dart

app/lib/core/utils/
  kiswahili_date.dart   -- `formatKiswahiliDate` (e.g. "21 Ago 2026")

app/lib/app/shell/      responsive navigation chrome
  app_shell.dart, shell_destination.dart

app/assets/branding/    official Umoja artwork (see "Brand assets" below)
  umoja_mark.png, umoja_wordmark.png

app/assets/fonts/       bundled Ubuntu static weights (Regular/Medium/Bold)
```

Widgets should style themselves via `Theme.of(context)` (colors, text
styles, component themes) rather than importing `UmojaColors`/
`UmojaTypography` directly — those tokens exist to build the theme in
one place, not to be scattered through feature code. Reach for the
`core/widgets` components before writing bespoke layout for anything
that looks like a page, section, card, list row, status pill, or empty/
error/loading state.

## Brand assets

Umoja's official brand artwork ships as two pre-cleaned, genuinely
transparent PNGs under `app/assets/branding/` (never regenerated or
redrawn at build time):

- **`umoja_mark.png`** — the umbrella/people symbol alone. The
  authoritative source for the app launcher icon / web favicon-PWA
  icon (via `flutter_launcher_icons`, below) and for provenance —
  never edited in place.
- **`umoja_wordmark.png`** — the custom "UMOJA" wordmark artwork,
  same role: authoritative source, never edited in place.

Both are rendered through `UmojaBrandMark` (`core/branding/`), which
offers `.symbol(size:)`, `.wordmark(wordmarkHeight:)`, and `.lockup(...)`
(symbol beside wordmark — the app's one symbol+wordmark composition;
there is no separate official combined lockup asset file, so every
context that needs both together, including the expanded desktop
sidebar, uses this same layout). `UmojaBrandMark` itself renders
**`umoja_mark_trim.png`/`umoja_wordmark_trim.png`** — a runtime-only
derivative of each source file, cropped to its own opaque bounding box
(plus a few native pixels of margin), generated once and committed
alongside the originals. This exists because both source PNGs carry a
large transparent margin baked into their canvas (safe-area padding
intended for the app-icon/favicon use, e.g. adaptive-icon inset —
irrelevant to on-screen widget rendering), which previously made
`.wordmark`/`.lockup` read as oddly overspaced no matter how tight the
explicit layout spacing was set (prompt 05D §16-17 — reported as "the
symbol and wordmark are spaced too far apart"). The trim never
stretches or distorts the artwork (the symbol crop stays square, since
`.symbol`/`.lockup` render it into a fixed `width == height` box; the
wordmark crop only affects its width, since only `wordmarkHeight` is
ever set and the image's own aspect ratio determines the rest) and
never cuts into actual glyph pixels — only the surrounding transparent
margin is removed. `.lockup`'s internal symbol-wordmark gap is
`UmojaSpacing.xs` (4px), matching the target visual gap now that both
assets are trimmed. Use the `_trim` derivatives only through
`UmojaBrandMark`; anything reading brand artwork outside that widget
(app-icon generation, below) still uses the authoritative originals.

**The wordmark artwork must never be recreated with the Ubuntu UI font
or redrawn** — it is supplied, authoritative artwork, not a text
string. The app's primary brand color (`UmojaColors.primary`) stays the
established deep Umoja red; the logo artwork's own brighter
red/gradient rendering is not used to redefine the app's interactive
color palette.

The app launcher icon / web favicon use the **symbol**, never the
wordmark — see `web/icons/`, `web/favicon.png`, `web/manifest.json`.

### Native launcher icons (prompt 05C §15-17)

Android shipped with Flutter's own default launcher icon until prompt
05C — confirmed on a real device before fixing it. Generated via the
`flutter_launcher_icons` dev-dependency (config lives in `pubspec.yaml`,
never hand-edited generated output) from two source images under
`app/assets/branding/icon/` (generation inputs only — deliberately
absent from `flutter: assets:`, since the app itself never loads them
at runtime):

- **`app_icon_legacy.png`** — `umoja_mark.png` flattened onto a white
  1024×1024 canvas (content ≈46%×56% of the canvas, a comfortable
  margin) — used for the pre-API-26 `mipmap-*/ic_launcher.png` set and
  for Web/PWA icons (`web/icons/`, `web/favicon.png`,
  `web/manifest.json`'s `theme_color`/`background_color`, now the
  brand red/white rather than Flutter's default blue).
- **`umoja_mark.png`** itself (already genuinely transparent — no
  chroma-key cleanup needed) as `adaptive_icon_foreground`, with
  `adaptive_icon_background: "#FFFFFF"` and
  `adaptive_icon_foreground_inset: 20` (a wider-than-default safe-zone
  margin, since the mark's own content already fills ~59-71% of its
  512px canvas) — generates
  `mipmap-anydpi-v26/ic_launcher.xml` + `drawable-*dpi/
  ic_launcher_foreground.png` + `values/colors.xml`, so Android's
  circular/squircle adaptive masks never crop the umbrella/people mark.
- **Only Android and Web are enabled.** iOS/Windows/macOS were
  deliberately left untouched — their build toolchains cannot be
  built/verified in a Linux-only environment, and blindly regenerating
  icon assets for a platform whose build can't be checked afterward
  risks a silent breakage nobody would catch. `AndroidManifest.xml`'s
  `android:icon="@mipmap/ic_launcher"` reference was already correct —
  only the underlying asset files needed replacing.
- Verified on both a real physical device (fresh install after
  `flutter clean`, confirming the new build runs correctly) and a full
  Android emulator runtime (home screen hotseat + app drawer
  screenshots — the umbrella/people mark renders correctly under the
  circular adaptive mask, fully visible, no cropping, Flutter's default
  logo gone). The physical device's own ADB input injection is blocked
  by a device security setting outside this environment's control, so
  the interactive screenshot comparison was done on the emulator (a
  real Android runtime, not a mock) instead — see the Prompt 05C report
  for the exact verification steps.

## Color palette

Semantic tokens in `UmojaColors` — never write a literal hex value in
feature code:

| Token | Hex | Use |
|---|---|---|
| `primary` | `#A51C30` | Primary brand actions, selected nav state |
| `primaryDark` | `#741421` | Text/icons on `primarySoft`, secondary brand tone |
| `primarySoft` | `#FBEAEC` | Selected-state fills (nav indicator, avatar background) |
| `background` | `#F7F8FA` | Scaffold background |
| `surface` | `#FFFFFF` | Cards, sheets, app bar |
| `surfaceSubtle` | `#F2F4F7` | Subtle elevated surface (skeleton bars, disabled fills) |
| `textPrimary` | `#171A21` | Primary text |
| `textSecondary` | `#667085` | Secondary text, labels |
| `textDisabled` | `#98A2B3` | Disabled text/hints |
| `border` / `borderStrong` | `#E4E7EC` / `#D0D5DD` | Card/input borders |
| `success` / `successSoft` | `#15803D` / `#ECFDF3` | ACTIVE-style status |
| `warning` / `warningSoft` | `#B54708` / `#FFFAEB` | SUSPENDED-style status |
| `danger` / `dangerSoft` | `#B42318` / `#FEF3F2` | Destructive actions, errors |
| `info` / `infoSoft` | `#175CD3` / `#EFF8FF` | Informational accents |

These feed a `ColorScheme` (`UmojaTheme`) via `ColorScheme.fromSeed(...).copyWith(...)`
— the seed gives Material 3 a complete, harmonious scheme, and the
`copyWith` pins the tokens that matter (primary, error, surface, text,
outline) to Umoja's exact palette rather than algorithmically-derived
ones.

## Typography

Ubuntu is Umoja's UI typeface — bundled as static font assets
(Regular/Medium/Bold, see `pubspec.yaml`), not a Google Fonts network
dependency. It is applied once, via `ThemeData(fontFamily: 'Ubuntu')`
in `umoja_theme.dart`; `UmojaTypography`'s `TextStyle`s deliberately
don't set their own `fontFamily`, so every text style — and any ad-hoc
`TextStyle` that doesn't override it — resolves to Ubuntu automatically
through Flutter's theme/text-theme merge (`ThemeData`'s
`defaultTextTheme.merge(textTheme)`, where only the base carries a
`fontFamily`).

**The brand wordmark artwork is separate from this typeface and is
never recreated with it** — see "Brand assets" above.

`UmojaTypography.textTheme(...)` builds a full Material `TextTheme`.
Hierarchy:

| Role | TextTheme slot | Size / weight |
|---|---|---|
| display / large title | `headlineMedium` | 22sp / 700 |
| page title | `titleLarge` | 22sp / 700 |
| section title | `titleMedium` | 16sp / 600 |
| card title | `titleSmall` | 15sp / 600 |
| body | `bodyLarge` | 15sp / 400 |
| secondary body | `bodyMedium` | 14sp / 400 |
| label | `labelLarge` | 14sp / 600 |
| caption | `bodySmall` | 12sp / 400 |

Body text never drops below 14sp; page titles scale from 22sp up
toward 26–28sp at the top of the `display`/`headlineLarge` slots for
screens that want more visual weight (none currently do — Home's
greeting is the closest, at `headlineMedium`). Text scaling
(accessibility) is never disabled.

## Spacing

`UmojaSpacing`: `xs=4, sm=8, md=12, lg=16, xl=20, xxl=24, xxxl=32,
huge=40, massive=48`. Page horizontal padding is responsive via
`UmojaBreakpoints.horizontalPadding()` — 16 below the mobile
breakpoint, 24 at and above it (`UmojaResponsiveContent` applies this
automatically; don't hand-roll page padding).

## Radius

`UmojaRadius`: `small=8, medium=12, large=16`; `control=12` (buttons,
inputs), `card=14` (cards). No pill-shaped containers outside genuine
pills (status badges, chips use their own Material shapes).

## Responsive breakpoints

`UmojaBreakpoints`: `mobile=700`, `desktop=1200`.

- `< 700`: phone layout — bottom `NavigationBar`, `AppBar` title, FAB
  for the primary page action.
- `700–1199`: tablet — compact `NavigationRail`, inline `UmojaPageHeader`
  instead of an `AppBar` title, primary action as a header button.
- `>= 1200`: desktop — extended `NavigationRail` (labels always
  visible), same inline header/content pattern as tablet.

Content never stretches edge-to-edge on wide viewports —
`UmojaResponsiveContent` centers content and caps its width. Guideline
max widths used so far: ~640 for forms (`MemberFormScreen`), ~900 for
detail/list views with a single content column (`MemberDetailScreen`,
`MembersListScreen`), ~1120 default for general content (`HomeScreen`,
`MoreScreen`). Pick the narrowest width that still reads comfortably
for the content type — a form should never be full-width on a 1440px
desktop.

## Navigation / app shell

`AppShell` (`app/lib/app/shell/app_shell.dart`) wraps every operational
route in a `ShellRoute` (see `app_router.dart`) and renders the
breakpoint-appropriate chrome around whatever screen is routed. Each
screen remains a self-contained `Scaffold` (via `UmojaPage`); `AppShell`
only adds navigation around it — screens don't need to know they're
inside a shell.

Destinations (`shell_destination.dart`) — **only real, implemented
modules belong here**:

| Destination | Route | Icon |
|---|---|---|
| Home | `/home` | `Icons.home_outlined` / `Icons.home` |
| Wanachama (Members) | `/members` | `Icons.people_alt_outlined` / `Icons.people_alt` |
| Zaidi (More) | `/more` | `Icons.more_horiz` |

Do not add a destination for Contributions/Loans/Wallet/Reports/etc.
until that module actually exists — see prompt 05 §10 and §50. Auth,
onboarding, splash, and `/access/*` routes stay outside the
`ShellRoute` entirely and never show this navigation.

**Sidebar branding**: `NavigationRail.leading` renders the Umoja brand
mark — `UmojaBrandMark.lockup` (symbol 52px + wordmark 44px tall,
sized up moderately in Prompt 05D §18 for clearer brand presence) when
the rail is extended (>= 1200px), `UmojaBrandMark.symbol` alone (36px)
when it is compact (700–1199px). `.lockup` keeps symbol and wordmark
visually grouped as one brand (a tight 4px gap, trimmed artwork — see
"Brand assets" above) rather than a large symbol and a far-away
wordmark as two unrelated widgets — still subtle, never full-bleed logo
artwork.

## Auth branding

`/auth/phone` (now the combined phone + PIN login screen), `/auth/verify`,
`/auth/pin-setup`, and the PIN recovery screens (see
`docs/product/authentication.md`) share `AuthScreenLayout`
(`features/auth/presentation/widgets/auth_screen_layout.dart`): a
`UmojaBrandMark.combined` (a single vertical symbol-above-wordmark
lockup, `wordmarkHeight: 100`). Since prompt 05E-A, content sits in a
balanced upper-middle column rather than pinned to the very top —
gaps above and below are sized as a fraction of the available viewport
(roughly 2:3, clamped to sane bounds) inside a scrollable, so the
keyboard opening on a PIN/OTP field never overflows and a short
viewport still reserves room for the top-left back-arrow overlay.
Screen content stays constrained to ~440px max width on every platform
(mobile and desktop alike). Auth screens are also forced to the light
Umoja theme regardless of system brightness — dark mode has not
received the same manual polish yet (see
`docs/product/authentication.md`, "Server-side PIN authentication").
"Umoja v2" is never shown to users — "v2" is an implementation/project
concept, not the consumer-facing brand; `AppConstants.appName` and
every user-facing surface just say "Umoja". The same brand mark also
appears on `SplashScreen` (wordmark on the config-missing branch,
symbol above the loading spinner otherwise), so the identity is
consistent from first frame to signed-in shell. The phone-entry screen
also carries the SW|EN language selector (`showLanguageSelector: true`,
the default) — see "Multi-language support" below; the other auth/PIN
screens set it to `false` since the choice is already made by then.

**PIN/OTP entry** (Prompt 05E §UX): `UmojaCodeInput`
(`core/widgets/umoja_code_input.dart`) replaces the earlier generic
`TextField` + separate `PinDots` indicator with a single boxed,
digit-style input — one bordered box per digit, filled with an
obscured dot as it's typed, matching common OTP/PIN UI conventions
instead of a long plain text field. An invisible `TextField`
(`Positioned.fill`, `Opacity: 0`) sized exactly to the visible box row
still captures real keyboard/SMS-autofill input and drives the boxes
via the same external `TextEditingController` every PIN/OTP screen
already owned — a drop-in visual replacement, not a rework of the
existing `AutoSubmitOnLength` auto-submit plumbing. Box width is
computed adaptively (`LayoutBuilder`, clamped 32–48px) so a 6-digit OTP
never overflows a narrow phone even though a 4-digit PIN comfortably
uses the full 48px box size. Used on `/auth/phone` (the PIN field),
`/auth/verify`, `/auth/pin-setup`, and `/auth/pin-recover/verify`. The
two OTP screens (`/auth/verify`, `/auth/pin-recover/verify`) also set
`isOneTimeCode: true` for iOS's native one-time-code autofill hint and
pair with Android SMS autofill (`OtpAutofill`, see
`docs/product/authentication.md`, "OTP SMS autofill") — the 4-digit PIN
screens never do either.

## Status semantics

`UmojaStatusBadge` takes a `label` (always shown as text — status
meaning is never color-only) and a `UmojaStatusSemantic`
(`success`/`warning`/`danger`/`info`/`neutral`). Each feature maps its
own domain status to a semantic; the mapping lives once per domain,
not per widget. For memberships (`memberStatusSemantic` in
`features/members/presentation/widgets/member_status_badge.dart`):
`ACTIVE → success`, `SUSPENDED → warning`, `EXITED → neutral`.

**Badge labels are localized (SW or EN, per the active language),
never the raw backend enum** — a separate `memberStatusLabel(l10n,
status)` mapping (same file, taking `AppLocalizations` since prompt
05C) translates for display only; the backend value itself never
changes:

| Backend (`group_memberships.status`) | Kiswahili | English |
|---|---|---|
| `ACTIVE` | Hai | Active |
| `SUSPENDED` | Amesitishwa | Suspended |
| `EXITED` | Ametoka | Exited |

`MemberStatusBadge` applies both mappings together (reading
`context.l10n` internally); any screen building its own
`UmojaStatusBadge` from a membership status (e.g. Home, More) must call
`memberStatusLabel(l10n, ...)` too — never pass the raw status string
as the badge label.

## Role labels

Backend role codes (`ADMIN`/`TREASURER`/`SECRETARY`/`CHAIRPERSON`/
`MEMBER`) are likewise never shown raw in polished UI.
`memberRoleLabel(l10n, code)`
(`features/members/presentation/widgets/member_role_label.dart`) maps
each to its localized label:

| Backend role code | Kiswahili | English |
|---|---|---|
| `ADMIN` | Msimamizi | Administrator |
| `TREASURER` | Mweka Hazina | Treasurer |
| `SECRETARY` | Katibu | Secretary |
| `CHAIRPERSON` | Mwenyekiti | Chairperson |
| `MEMBER` | Mwanachama | Member |

Authorization always checks the backend role code (via
`hasPermission`/`roleCodes`), never this display label.

## Localization architecture (Prompt 05B)

Prompt 05A tightened the app's copy to Kiswahili-first but left it as
inline literal strings per widget. Prompt 05B replaced that with
Flutter's standard localization architecture — `flutter_localizations`
+ `gen-l10n` + ARB files — so strings stop being scattered across
widgets:

- **Source of truth**: `lib/l10n/app_sw.arb` (the *template* — see
  `l10n.yaml`) and `lib/l10n/app_en.arb`, one key per string, with
  ICU placeholders (`{phone}`, `{seconds}`, `{name}`, `{roles}`) where
  needed. `flutter gen-l10n` (auto-run via `pubspec.yaml`'s
  `generate: true`) produces `lib/l10n/app_localizations*.dart` —
  generated, not hand-edited, and committed like any other generated
  Flutter localization output.
- **Usage**: `context.l10n.someKey` (a tiny extension,
  `core/localization/app_localizations_x.dart`, over
  `AppLocalizations.of(context)!`) — never a raw string literal for
  anything user-facing on a currently-implemented screen.
- **Language selection**: `languageProvider`
  (`core/localization/language_provider.dart`) holds the current
  `AppLanguage` (`swahili` default, `english`), persisted via plain
  `SharedPreferences` (a device/browser UI preference, not a secret —
  unlike the PIN, which must never live there; see
  `docs/product/authentication.md`). `UmojaLanguageSelector`
  (`core/widgets/umoja_language_selector.dart`) is a plain SW|EN
  `SegmentedButton` — **text, never flags** (a flag denotes a country,
  not a language) — shown on the phone-entry screen (reachable before
  login) and in More's own "Lugha" section.
- **Errors are localized by type, not by a baked-in string**:
  `AuthFailure`/`MemberFailure` carry a `type` enum (already existed
  for classification) plus their original English `message` for logs
  only; `core/localization/failure_messages.dart`'s
  `authFailureMessage`/`memberFailureMessage` map `type` to the
  current-language string at *display* time, so the same failure
  reads correctly regardless of when the language was switched
  relative to when the error occurred. Simple client-side-only
  validation (e.g. "name required") reuses the same `MemberFailureType`
  enum via a `nameRequired` case rather than inventing a parallel
  mechanism.
- **Backend enum/API codes are never translated or altered** — only
  their display presentation is (see "Status semantics"/"Role labels"
  below, and `docs/product/members.md`). Dates use
  `formatKiswahiliDate` (`core/utils/kiswahili_date.dart`, e.g.
  "21 Ago 2026") instead of a raw ISO string — display-only.
- **Scope**: every currently-implemented user-facing screen goes
  through this system, including the `/access/*` screens (account-
  disabled, context-error, group-suspended/closed, membership-
  restricted) and the app shell's navigation (bottom bar/rail labels,
  built from `shellDestinations(l10n)` — a function of the current
  language, not a top-level `const`). Prompt 05C's audit found and
  fixed the remaining gaps left by 05B: those five `/access/*` screens,
  the shell nav labels, `select_group_screen.dart`, the splash screen's
  config-missing notice, and the `UmojaErrorState`/"Clear search"
  strings were all hardcoded English literals regardless of the active
  language — do not assume any current screen is still like that
  without checking.

## Core components

- **`UmojaPage`** — standard screen scaffold: `AppBar` title on mobile,
  inline `UmojaPageHeader` on tablet/desktop (never both — see prompt
  05 §12), optional FAB (mobile-only; desktop gets the same action via
  `headerTrailing`), optional scroll wrapping. `backTo`/`backLabel` give
  a nested route (member detail, member form) an explicit,
  deep-link-safe way back to its parent, instead of relying on
  `Navigator.canPop` (false when the route was reached directly — a
  deep link, a fresh web load — even though a parent conceptually
  exists): mobile gets an explicit back arrow in the `AppBar`;
  desktop/tablet gets a small "← [backLabel]" link above the inline
  page header, since that breakpoint has no `AppBar` title to carry a
  back arrow at all.
- **`UmojaSection`** — a titled group of content (Taarifa za
  Mwanachama, Uanachama, Majukumu, Vitendo on member detail). Lighter
  than a card — not every field needs its own card.
- **`UmojaCard`** — bordered, flat surface with consistent padding.
- **`UmojaListTile`** — leading widget + title + subtitle + trailing +
  chevron; the shape behind member rows and the Home shortcut.
- **`UmojaStatusBadge`** — see above.
- **`UmojaEmptyState`** / **`UmojaErrorState`** / **`UmojaLoadingState`**
  — consistent icon+title(+message/action), friendly-message-with-Retry,
  and a static skeleton-row placeholder (no shimmer dependency),
  respectively. `UmojaErrorState` never renders raw exception text.
- **`UmojaSearchField`** — search icon, clear button once there's text;
  purely presentational, debounce stays with the caller.
- **`UmojaPrimaryButton`/`UmojaSecondaryButton`/`UmojaDangerButton`** —
  filled/outlined/danger hierarchy, inline loading spinner without
  layout shift, 48px minimum touch height (from the theme's button
  styles).
- **`UmojaFormSection`** — titled group of form fields with consistent
  spacing.
- **`UmojaResponsiveContent`** — centers + width-caps + responsively
  pads content; used by `UmojaPage` internally.
- **`UmojaConfirmationSheet`** (`showUmojaConfirmationSheet`) — modal
  bottom sheet for confirming a potentially destructive action (suspend,
  mark as exited). `title` and `confirmLabel` are separate parameters
  deliberately — giving them identical text makes the two easy to
  confuse when scripting/testing against them, even though a real user
  only ever sees one at a time (the sheet, once open, visually replaces
  the trigger).
- **`UmojaInitialsAvatar`** — deterministic initials (e.g. "Fredrick
  Mrema" → "FM"), no stored images, no random per-rebuild color.

## Mobile vs desktop layout summary

| | Mobile (< 700) | Tablet/Desktop (>= 700) |
|---|---|---|
| Navigation | Bottom `NavigationBar` | `NavigationRail` (extended >= 1200) |
| Page heading | `AppBar` title | Inline `UmojaPageHeader`, no `AppBar` title |
| Primary page action | FAB | Button in the inline header |
| Content width | Full width (minus 16px padding) | Capped + centered (minus 24px padding) |

## Rules for future module UI (Contributions, Payments, Wallet, Hisa, Loans, Financial Accounts, Reports)

1. Build every screen from `UmojaPage` + the `core/widgets` components
   above; don't invent new page chrome, button styles, or status pill
   treatments.
2. Add a shell destination only once the module is real and
   implemented — never as a placeholder.
3. Never show fabricated data (a zero balance, "0 loans", etc.) — an
   honest empty state is the correct UI for a module with no data yet.
4. Map the module's own domain status to `UmojaStatusSemantic` once,
   in one place, the same way `memberStatusSemantic` does — don't
   reimplement color logic per widget.
5. Reuse `UmojaConfirmationSheet` for destructive actions instead of a
   bespoke `AlertDialog`.
6. Respect the same responsive width guidelines (forms ~640, detail
   views ~900, general content ~1100–1200) unless the content genuinely
   needs something else.
7. Present Kiswahili-first UI copy; map any new domain status/role/enum
   to its own display label once, in one place (the same way
   `memberStatusLabel`/`memberRoleLabel` do) — never expose a raw
   backend enum string in polished UI, and never translate the backend
   value itself.
8. Reuse `UmojaBrandMark`/Ubuntu — never introduce a different typeface
   or recreate/redraw the brand artwork for a new module's screens.
