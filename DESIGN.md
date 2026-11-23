---
name: BlueTrack
description: A calm, evidence-led marine conservation donation platform.
colors:
  ocean: "#0284C7"
  ocean-deep: "#075985"
  teal: "#14B8A6"
  coral: "#FF6F61"
  canvas: "#F6F9FC"
  surface: "#FFFFFF"
  ink: "#0F172A"
  slate: "#64748B"
  hairline: "#E2E8F0"
  success: "#16A34A"
  warning: "#F59E0B"
  danger: "#DC2626"
  inactive: "#94A3B8"
typography:
  display:
    fontFamily: "PlusJakartaSans, sans-serif"
    fontSize: "38px"
    fontWeight: 800
    lineHeight: 1.1
  headline:
    fontFamily: "PlusJakartaSans, sans-serif"
    fontSize: "24px"
    fontWeight: 800
    lineHeight: 1.25
  title:
    fontFamily: "PlusJakartaSans, sans-serif"
    fontSize: "18px"
    fontWeight: 700
    lineHeight: 1.3
  body:
    fontFamily: "PlusJakartaSans, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "PlusJakartaSans, sans-serif"
    fontSize: "12px"
    fontWeight: 600
    lineHeight: 1.2
  button:
    fontFamily: "PlusJakartaSans, sans-serif"
    fontSize: "16px"
    fontWeight: 700
    lineHeight: 1.2
rounded:
  sm: "12px"
  md: "16px"
  pill: "999px"
  sheet: "24px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  xxl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.coral}"
    textColor: "{colors.surface}"
    typography: "{typography.button}"
    rounded: "{rounded.md}"
    padding: "0 16px"
    height: "52px"
  button-primary-ocean:
    backgroundColor: "{colors.ocean}"
    textColor: "{colors.surface}"
    typography: "{typography.button}"
    rounded: "{rounded.md}"
    padding: "0 16px"
    height: "52px"
  button-outlined:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ocean}"
    typography: "{typography.button}"
    rounded: "{rounded.md}"
    padding: "0 16px"
    height: "52px"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "14px 16px"
    height: "52px"
  chip-selected:
    backgroundColor: "{colors.ocean}"
    textColor: "{colors.surface}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "8px 14px"
  chip-unselected:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "8px 14px"
  card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "16px"
  nav-bar:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ocean}"
    typography: "{typography.label}"
    height: "68px"
---

# Design System: BlueTrack

## Overview

**Creative North Star: "The Tide Ledger"**

BlueTrack should feel like a well-kept ledger carried across open water: calm, legible, and accountable. The ocean is present as a system of color and rhythm, never as decoration for its own sake. A donor should be able to read a screen the way they read a receipt — find the amount, find the evidence, find the next step — without noise competing for attention.

The interface is mobile-first, light, and quietly dense. White cards sit on a cool paper-blue canvas, separated by a hairline rather than a shadow. Ocean blue carries structure and navigation; teal marks verification and progress; coral is held back for the single action that matters on a screen. Numbers are allowed to be the loudest element on the page because the product's promise is that numbers can be trusted.

The visual rejection is deliberate: no campaign-poster gradients, no gamified badges, no celebratory confetti around money, no dark patterns that push a donation. Trust is communicated through restraint, adjacency of evidence, and consistent repetition — not through urgency.

**Key Characteristics:**
- Cool paper-blue canvas with white, hairline-bordered cards.
- One typeface, used with discipline; financial figures carry the hierarchy.
- Ocean for structure, teal for proof, coral for the single primary action.
- Flat surfaces; depth from tone and border, not shadow.
- Generous 16dp gutters and 48dp touch targets.
- Indonesian-first copy, calm and factual in both languages.

## Colors

A cool, marine palette with one warm accent; saturation is concentrated in small areas, not spread across surfaces.

### Primary
- **Ocean Blue** (#0284C7): brand and structure. App bar accents, active tab, links, progress, selected chips, and every primary amount. This is the color a donor associates with BlueTrack.
- **Deep Ocean** (#075985): reserved for high-emphasis text on light ocean tints and for pressed/deep states; it keeps the brand from becoming neon.

### Secondary
- **Verification Teal** (#14B8A6): proof and growth. Verified badges, completed checklist icons, the far end of the funding-progress gradient, and positive confirmation. Teal is never used for a call to action.

### Tertiary
- **Coral** (#FF6F61): the action accent. Primary CTA fill (donate, continue, sign in where the action is the point), notification counts, and small moments of human warmth. It is a signal, not a surface.

### Neutral
- **Paper Blue** (#F6F9FC): the app canvas. Every scrollable page sits on it.
- **Surface White** (#FFFFFF): cards, inputs, app bars, bottom navigation.
- **Ink** (#0F172A): primary text; also the floating snackbar fill.
- **Slate** (#64748B): secondary text, metadata, unselected labels.
- **Hairline** (#E2E8F0): 1px card borders, input borders, dividers, progress track.
- **Inactive** (#94A3B8): unselected bottom-nav icons and labels.
- **Signal colors:** success #16A34A, warning #F59E0B (offline banner), danger #DC2626 (errors only, never for a failed grant selection).

### Named Rules
**The One Coral Rule.** Coral marks the single primary action on a screen. It may fill a button or a small badge; it never becomes a page background, a large card, or decorative chrome. If two coral elements compete, one of them is wrong.

**The Ocean Means Structure Rule.** Ocean blue is the default for navigation, links, selected states, and financial figures. Teal means "verified or progressing"; using teal for a normal button erodes its evidentiary meaning.

## Typography

**Display Font:** Plus Jakarta Sans (with system sans-serif fallback)
**Body Font:** Plus Jakarta Sans (same family; weights 400–800)
**Label Font:** Plus Jakarta Sans

**Character:** One humanist geometric family, tightly weighted. The voice is friendly but not playful: 400 for reading, 600 for labels, 700 for titles and buttons, 800 for figures and page-level emphasis. There is no second typeface and no italic voice.

### Hierarchy
- **Display** (800, 38/30, 1.1): hero financial figures only — donation amount, trace total. Never a page title.
- **Headline** (800, 24/20, 1.25): page and section headings; 20 is the app-bar title.
- **Title** (700, 18/16, 1.3): project-card titles, sheet titles, list-item names.
- **Body** (400, 14/12, 1.5): standard copy and metadata; 12 is the floor for readable body text.
- **Label** (600–700, 12/11, 1.2): chips, badges, nav labels, progress captions. 11 is reserved for compact badges, not paragraphs.
- **Button** (700, 16, 1.2): every filled and outlined action.

### Named Rules
**The Numbers Carry the Hierarchy Rule.** When a screen contains an amount, a percentage, or a date that proves impact, that figure gets the largest weight on the page. Decorative headings step back.

**The One Family Rule.** Plus Jakarta Sans is the only typeface. New screens do not introduce a display serif, a mono face, or a second sans.

## Layout

Compact Android phone is the design target. Content uses a 16dp horizontal gutter (`AppDimens.padding`) and a vertical rhythm of 4 / 8 / 12 / 16 / 24 / 32dp, with 8 and 12 dominant between related elements. Cards are full-width within the gutter; gallery media is 16:9 and clips to the card's top corners.

Primary screens follow one of two shapes: a scrolling feed of cards (Explore, Impact, Profile) or a single-column task flow with a sticky bottom action (Donation, Report). Bottom actions are 48–52dp tall and sit above the system navigation inset. The app shell reserves 68dp for the Material 3 navigation bar and shows the offline banner above content, never over it.

The layout is intentionally single-column; there is no tablet-specific rail or two-pane layout yet. New work should not stretch the phone layout across a tablet without adding a proper window-size adaptation.

## Elevation & Depth

The system is flat. Structure comes from three layers only: the paper-blue canvas, the white surface, and the hairline border. Cards use `elevation: 0`; the app bar is flat at rest and only reaches 0.5 elevation when content scrolls under it. There is no ambient drop shadow on cards, buttons, or the nav bar.

The few shadows that exist are functional, not structural: the category pill and bookmark over a project gallery cast a soft 6dp shadow so white controls remain legible on arbitrary photography. Bottom sheets use Material 3's scrim and a 24dp top radius instead of a shadow.

### Shadow Vocabulary
- **Gallery control lift** (`0 2px 6px rgba(0,0,0,0.13)`): only for white pills/icons floating over imagery, to guarantee contrast.
- **Scrolled app bar** (`elevation: 0.5`): a hint that content continues underneath, not a decorative elevation.

### Named Rules
**The Flat Water Rule.** Structural surfaces are flat. If a card needs a shadow to be understood, the border, spacing, or background tone is wrong.

## Shapes

The form language is soft and rounded, never pill-shaped for containers and never sharp. Primary containers — cards, filled buttons, outlined buttons, inputs — use a 16dp radius (`AppDimens.cardRadius`). Nested tiles, thumbnails, and compact info blocks use 12dp. Pills, chips, badges, and the save button use a full 999dp radius. Bottom sheets use 24dp on the top corners only. Progress bars are fully rounded (height ÷ 2).

Radii are not decorative variation: 16 means "this is a primary surface", 12 means "this sits inside one", 999 means "this is a token or a control".

### Named Rules
**The 16/12/999 Rule.** Primary surfaces are 16dp, nested surfaces are 12dp, and pills are fully rounded. A new radius needs a reason, not a preference.

## Components

### Buttons
- **Shape:** 16dp radius, 52dp minimum height, full-width by default in task flows.
- **Primary (coral):** `PrimaryButton` default. One per screen, reserved for the action the screen exists to perform.
- **Primary (ocean):** the same button with `color: AppColors.ocean`, used when the action belongs to the brand/navigation layer — sign-in, login prompt, donate-from-card.
- **Outlined:** white fill, 1px ocean border, ocean label; for secondary actions that must remain visible.
- **Loading:** the label is replaced by a 22dp white circular indicator; the button stays at full height and becomes disabled.
- **Hover / Focus:** Material ripple and focus overlay; no custom hover color.

### Chips
- **Style:** `ChoiceChip`, white fill, 1px hairline border, 13px 600 label.
- **State:** selected = ocean fill, white label, no checkmark; unselected = white with ink label.
- **Touch:** padded Material tap target keeps the hit area at 48dp even though the chip is shorter; 8dp gap between chips.

### Cards / Containers
- **Corner Style:** 16dp.
- **Background:** white on paper blue.
- **Shadow Strategy:** none; see Elevation & Depth.
- **Border:** 1px hairline #E2E8F0.
- **Internal Padding:** 16dp standard; 20dp for the centered login-prompt card.
- **Media:** 16:9 gallery clipped to the top corners, with a 60%-black top gradient behind white overlay controls.

### Inputs / Fields
- **Style:** white fill, 16dp radius, 1px hairline border, 14dp vertical padding, 16dp horizontal padding.
- **Focus:** 2px ocean border; no glow or shadow.
- **Error:** 1px danger border plus the field's error text; never color alone.
- **Disabled:** Material default reduced-emphasis treatment; do not invent a new gray.

### Navigation
- **Style:** Material 3 `NavigationBar`, 68dp tall, white surface, four destinations in Release 1.
- **Selected:** ocean icon and 700 label on a 12%-ocean indicator pill.
- **Unselected:** #94A3B8 icon and 500 label.
- **Behavior:** each tab preserves its own scroll position and history; the bar is never hidden on scroll.

### Signature: Project Card
The recurring unit of Explore and the organization profile. A 16:9 generated wave gallery carries a category pill (top-left) and a 48dp frosted bookmark (top-right). The body reads top-to-bottom as a ledger: title (18/700), organization (14) with a compact teal verified icon, location (12), funding percentage (12/700 ocean), an 8dp ocean→teal progress bar, raised amount (20/800 ocean), target (12 slate), and a 48dp ocean donate button. The card is the product's thesis in miniature: claim, proof, amount, action.

### Signature: Verified Badge
A teal 10%-opacity pill with a 14dp verified icon and an 11/700 teal label; compact mode is the 16dp icon alone. Tapping opens a bottom sheet that explains what verification means and lists the four checks. The badge is never decorative: it always has an explanation one tap away.

### Signature: Progress Bar
An 8dp fully rounded track in hairline, filled by a horizontal ocean→teal gradient. The gradient is the only place the two brand colors blend; it reads as "money turning into verified progress".

### Offline Banner
Full-width warning #F59E0B strip above shell content, with a 16dp cloud-off icon and 12/600 white text. It is informational, not blocking; saved projects and reports remain usable underneath.

## Do's and Don'ts

### Do:
- **Do** use `AppColors` and `AppDimens`; a raw hex or radius in a widget is a bug in the system.
- **Do** keep 16dp page gutters and 8/12dp gaps between related elements.
- **Do** use 16dp for primary surfaces, 12dp for nested surfaces, 999dp for pills.
- **Do** let the financial figure or the evidence be the largest, loudest element on the screen.
- **Do** keep one coral primary action per screen and use ocean for structural actions.
- **Do** give every verification badge, progress figure, and impact number a visible explanation or source.
- **Do** keep every touch target at least 48dp and test at large system font sizes.
- **Do** use Material 3 components and Material Icons; theme them, don't replace them.

### Don't:
- **Don't** add drop shadows to cards, buttons, or the nav bar for structure.
- **Don't** use coral for page backgrounds, large cards, or decoration.
- **Don't** introduce a second typeface, a mono face, or a new display style.
- **Don't** invent a new radius, font size, or spacing step per screen.
- **Don't** use teal for ordinary actions; it means verified or progressing.
- **Don't** show the word "ditolak" for a failed grant selection; use "Belum lolos seleksi siklus ini".
- **Don't** assume a dark theme exists; the app currently ships a light-only scheme.
- **Don't** let content sit under the status bar, navigation bar, or keyboard.
