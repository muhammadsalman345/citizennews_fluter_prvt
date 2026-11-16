# CitizenNews Flutter

Clean Flutter implementation of the CitizenNews mobile application. The Ionic application remains
the product and UI reference while features are ported module by module.

## Completed modules

Module 1 provides the responsive application shell, Ionic-matched theme, branding, navigation,
routing, base folder architecture and placeholder routes for upcoming features.

Module 2 provides direct Supabase initialization, persistent auth sessions, signup, login, email
OTP confirmation, resend cooldown, username availability, international phone validation,
forgot/reset password, recovery deep links, route guards, account display and logout.

Module 3 provides the Ionic-matched country and city directory, country/region filters, paged city
search, a reusable location picker, saved device selection and precise GPS resolution through the
existing Supabase `resolve-location` Edge Function.

Module 4 adds fail-closed account-status and role authorization, reporter/admin route boundaries,
the complete Ionic route map and admin/super-admin workspace entry points.

Module 5 adds required signup country/city metadata, private identity-document uploads, live selfie
capture, country-specific ID validation, verification status/resubmission, and an audited admin
review queue with five-minute signed evidence URLs and approve/reject/suspend RPC actions.

Module 6 connects the public home/latest/trending/worldwide/search feeds to the existing
`search_news_global` RPC with database-driven categories, paging, reading-location filters and
loading/error/empty states.

Module 7 adds the live public article page with a safe structured-body renderer, public image
gallery, correction history, throttled view recording, reactions, bookmarks, reporter follows,
comments/replies/deletion, story/comment reports and share-link copying.

Module 8 adds reporter news submission using the Ionic application's unchanged Supabase contract:
report-purpose GPS tickets, database categories and job deadlines, zero-to-five private evidence
photos, camera-only accident enforcement, TipTap-compatible structured article JSON, silent local
draft recovery, idempotent uploads/submission, changes-requested resubmission and published-story
correction revisions.

Module 9 adds the reporter My Stories workspace and the admin news-moderation queue. Reporters can
filter statuses, read exact editorial reasons, edit/resubmit, open public stories/analytics and
appeal rejected or removed work. Admins review private signed evidence, exact capture context,
reporter trust, risk flags and duplicate candidates, then use the existing audited moderation,
breaking, incident-grouping and super-admin deletion RPCs. Publishing copies only reviewed evidence
to stable paths in the public `news-images` bucket.

Module 10 adds owner-only article analytics and the editorial correction-review queue. Analytics
uses the existing `article_analytics` RPC for 7/30/365-day verified readership, engagement and
points. Admin correction approval/rejection uses `news_revisions` and `review_revision`; the public
story remains unchanged until approval, then becomes corrected and retains its public correction
history.

Module 11 adds the reporter dashboard, points ledger, wallet and withdrawal request/history plus
the public reporter leaderboard. It reuses the exact Ionic economy tables and `reporter_dashboard`,
`leaderboard`, `my_wallet_summary` and `request_withdrawal` RPC contracts.

Module 12 adds the complete signed-in account workspace: editable profile and independent home-city
selection, normalized avatar upload with owned-file cleanup, saved stories, following management and
following feed, comment history, appeals and content-report history, password changes, plus audited
account-deletion request/cancellation. The module uses the existing Ionic Supabase tables, storage
bucket, RLS policies and deletion RPCs without changing the backend contract.

Module 13 connects country, region, city and category routes to `search_news_global`, including
slug validation, scoped search, latest/trending sorting, category, area and date filters, paging and
city/area/category follows. Explore now opens the canonical scoped routes. Public reporter profiles
use `public_reporters`, `reporter_statistics` and `public_news` for safe profile details, reputation,
published stories, follow/unfollow and verified-chat entry points.

Module 14 adds verified-member private chat using the existing Ionic Supabase contract. It includes
the eligibility gate, realtime inbox and unread state, unique-username member search, direct reporter
conversation routes, paged message history, retry-safe sending, lifecycle refresh, block/unblock and
audited message reporting. Account activity and identity verification remain enforced by backend RLS
and the existing chat RPCs.

Module 15 completes the remaining role-protected admin workspace: overview counts and recent audit,
content and chat-report resolution, appeal decisions, account/role/trust/points controls, deletion
request review, withdrawal approval/rejection/manual payment confirmation, super-admin wallet
adjustments, categories, global city creation, JSON settings, contact inbox and audit history. Every
privileged mutation uses the existing Ionic RPC/RLS contract and preserves server-side audit rules.

Module 16 ports the complete Ionic legal and support copy for About, Privacy, Terms, Community
Guidelines, Editorial Policy, Corrections, Content Removal and Copyright. The public Contact page
validates the Ionic field limits and submits through the existing rate-limited `send_contact` RPC.
Legal pages are linked from signup, account settings and desktop/mobile navigation.

Module 17 adds persisted application localization for English, Urdu, Arabic, Spanish, French and
German. It restores the Ionic `citizennews-language` preference contract, applies automatic RTL for
Urdu and Arabic, supplies locale-aware date/number helpers and exposes language selection in the
desktop header, guest mobile menu and signed-in account settings. Missing strings safely fall back
to English; reporter-authored content is never machine-translated.

Module 18 ports the Android AdMob policy with Google demo units enabled by default. It includes UMP
consent and privacy choices for production, ad-safe native feed placements, qualified-read and daily
interstitial caps, third-session/background-only app-open ads, optional rewarded ads with a temporary
ad-free period, post-submission reward choice, persistent frequency state and click-traffic protection.
Authentication, chat, reporting, account, administration and legal routes remain interruption-free.

The old standalone Node.js REST client has been removed. Flutter uses the same Supabase platform,
RPC functions and row-level security policies as the Ionic application.

The location module requires the Ionic geography migrations/data and the deployed
`resolve-location` Edge Function. Android and iOS request foreground location only; background
location is not enabled.

## Supabase configuration

Copy `config.example.json` to the ignored `config.json` and fill in the public project URL and
publishable/anon key. Never put a service-role or secret key in the mobile application.

Add `citizennews://reset-password` to the Supabase Auth redirect URL allow list. Keep the Ionic
signup email template configured with the six-digit `{{ .Token }}` value.

## Run

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=config.json
```
