# CitizenNews Ionic to Flutter parity audit

Audit date: 2026-11-07  
Reference application (read-only): `F:\Google\citizennews-private-transfer-v3-2026-10-25\citizennews`  
Flutter application: `C:\Users\salma\Desktop\Citizennews\citizennews-flutter`

## Purpose and safety boundary

This is the implementation checklist for bringing Flutter to feature and business-rule parity with the existing Ionic application. The Ionic source, its 28 Supabase migrations, RLS policies, Storage rules and RPCs are the product/backend contract.

- No Ionic files, Supabase migrations or live database data were changed during this audit.
- Do not create a second database or duplicate server rules in Flutter.
- Flutter must use the existing public/publishable Supabase key. A service-role key must never be shipped in the app.
- Flutter Android advertising must reuse Ionic's production/test AdMob app and unit IDs, consent flow,
  route placements, frequency caps, click protection and rewarded ad-free behavior from
  `src/app/core/ads.ts` and `ads-policy.ts`; debug builds must never request production units.
- Every feature will be implemented only after the owner approves that checklist item.
- Completion means real UI + live Supabase integration + permission/error/loading states + tests. A placeholder screen is not complete.
- Source inspection cannot prove which migrations are deployed in the live Supabase project. Before using a feature, verify its tables/RPCs non-destructively against the configured project.

## Executive result

Flutter is currently an early port, not a feature-complete replacement.

### Implemented in Flutter

- App bootstrap, theme, responsive desktop/mobile shell and bottom navigation.
- Supabase initialization using a publishable/anon key.
- Auth session persistence and profile/role loading.
- Login, signup, email OTP, OTP resend cooldown, username availability, forgot password and reset password.
- Basic account display and sign out.
- Country/region/city directory, saved reading location and GPS-based `resolve-location` lookup.

### Partial or misleading in Flutter

- Legal/support pages and AdMob privacy-choice controls are connected.
- Admin workspace tabs are connected; live role-by-role acceptance remains.
- Push notifications and offline/native lifecycle parity remain.
- Implemented modules still require the owner's final device and live-backend acceptance.

### Overall gap

Flutter now contains the main public-news, reporter, account, moderation, economy, verified-chat, admin and legal/support workflows. The largest remaining functional gaps are native services, advertising/consent, notifications and release acceptance. Server-enforced identity, evidence, moderation and financial rules must remain unchanged during the remaining port.

## Route and page parity

Status legend: **Present**, **Partial**, **Placeholder**, **Missing**.

### Public and authentication pages

| Ionic route/page | Flutter status | Missing work |
|---|---|---|
| `/` home/nearby feed | Partial | Connect `search_news_global`/public news, real cards, paging, cache, ads policy and states. |
| `/latest` | Placeholder | Latest feed query and paging. |
| `/trending` | Missing | Trending query and route. |
| `/world` | Missing | Worldwide feed. |
| `/explore`, `/search` | Partial | Directory exists; story search, filters and navigation into feeds do not. |
| `/country/:slug` | Partial | Live scoped feed implemented; device acceptance remains. |
| `/region/:countrySlug/:slug` | Partial | Live scoped feed implemented; device acceptance remains. |
| `/city/:countrySlug/:slug` | Partial | Live feed, area filters and follow actions implemented; device acceptance remains. |
| `/category/:slug` | Partial | Database-driven feed and category follow implemented; device acceptance remains. |
| `/news/:slug` | Missing | Full article page and engagement. |
| `/reporters` | Placeholder | Period/scope leaderboard. |
| `/reporter/:username` | Partial | Profile, stats, stories, follow and message entry implemented; device acceptance remains. |
| `/welcome` | Present | Review visual/copy parity later. |
| `/login` | Present | Live acceptance still required. |
| `/signup` | Partial | Add country/city contract and verify metadata parity. |
| `/otp` | Present | Live email delivery acceptance required. |
| `/forgot-password`, `/reset-password` | Present | Deep-link/device acceptance required. |
| not-found page | Missing | Add explicit user-friendly 404/error route. |

### Signed-in account and community pages

| Ionic route/page | Flutter status | Missing work |
|---|---|---|
| `/account` | Partial | Edit full name/bio, avatar upload/cleanup, status and links to all workspaces. |
| `/settings` | Missing | Profile/settings mode and account controls. |
| `/saved` | Missing | Bookmark list. |
| `/following` | Missing | Followed reporters/cities/areas/categories and unfollow. |
| `/comments` | Missing | User comment history. |
| `/appeals` | Missing | Verification/news appeals, statuses and admin responses. |
| `/messages` | Present | Device/live-backend acceptance remains. |
| `/messages/:peer` | Present | Opens an existing/new verified conversation by user ID; device acceptance remains. |
| `/verification` | Placeholder | Full private identity verification and resubmission flow. |

### Reporter pages

| Ionic route/page | Flutter status | Missing work |
|---|---|---|
| `/report-news` | Present | Live shared-backend GPS/evidence/editor/preview/submission flow. |
| `/report-news/edit/:id` | Present | Changes-requested resubmission and published correction revision flow. |
| `/dashboard` | Missing | Reporter summary and performance charts. |
| `/my-stories` | Present | Status filters, reasons/notes, edit/resubmit, public view, analytics entry and appeal actions. |
| `/points` | Missing | Points total and ledger. |
| `/wallet` | Missing | Wallet summary, ledger, payout form and withdrawal history. |
| `/analytics/:id` | Present | Owner/admin-enforced article totals, verified views, engagement, points and daily readership. |

### Admin and super-admin workspace

Flutter has the role-protected `/admin` workspace with live verification and news moderation tabs.
The workspace keeps all 15 Ionic tab routes registered and connected:

1. Overview counts and recent audit activity. **Present.**
2. Verification queue, private signed ID/selfie access, decrypted reviewer context and attempt history. **Present.**
3. News moderation queue, evidence/media, GPS/risk/device context and duplicate candidates. **Present.**
4. Published revision review. **Present.**
5. News/comment report handling. **Present.**
6. Chat-message report handling, including optional sender suspension. **Present.**
7. Appeal approval/rejection. **Present.**
8. User administration: suspend/reactivate, trusted reporter and admin role management. **Present.**
9. Account deletion requests. **Present (read-only, matching Ionic).**
10. Withdrawal approval, rejection and manual paid confirmation. **Present.**
11. Category management. **Present.**
12. Location/city management. **Present.**
13. Super-admin settings editor. **Present.**
14. Contact-message queue. **Present.**
15. Audit log. **Present.**

Super-admin-only actions that must remain server-enforced include wallet adjustments, settings changes, admin/trusted-reporter role changes, permanent post deletion and protections around the final active super admin.

### Legal and support pages

`/terms`, `/privacy`, `/community-guidelines`, `/about`, `/editorial-policy`,
`/corrections-policy`, `/content-removal` and `/copyright` now render the Ionic English policy copy.
`/contact` validates and submits to the existing anonymous/authenticated `send_contact` RPC with its
daily rate limit. AdMob privacy-option controls remain pending until the ads/consent module exists.

## Missing business logic

### P0 - Identity, roles and access control

- [ ] Refresh `my_roles` before sensitive navigation and deny access when permission verification fails.
- [ ] Add route-level auth, reporter, admin and super-admin guards.
- [ ] Respect `account_status`; a suspended account must not retain reporting/admin capability in the client.
- [ ] Normal users can browse and engage, but only approved reporters can submit news.
- [ ] Admin visibility in the UI is convenience only; every action must still use the existing RLS/RPC enforcement.

### P0 - Identity verification lifecycle

- [ ] Load country-specific ID types with `government_id_types`.
- [ ] Collect ID type/number, required front/back images, live selfie, country/city and optional DOB.
- [ ] Upload to private `identity-documents` and `selfies` buckets under the authenticated user's path.
- [ ] Call `submit_identity`; never store raw ID numbers locally or publicly.
- [ ] Show pending, approved, rejected and suspended states, exact reason/note, history and resubmit/appeal actions.
- [ ] Preserve backend rules: email must be verified, PK CNIC is 13 digits, passport format/DOB bounds apply, document ownership is checked and one identity is permanently bound to its original owner.
- [ ] Admin inspection must call `audit_document_access`, request short signed URLs and use `verification_context`; private document URLs must never become public URLs.
- [ ] Admin approve grants reporter-related records; reject/suspend requires valid reasons and audit history.

### P0 - Reporter news submission

- [ ] Three-stage editor: category/details, live location/media, story/preview/send for review.
- [ ] Request high-accuracy current GPS for reporting separately from the user's reading-location selection.
- [ ] Use `resolve-location` with reporting purpose and preserve its server-issued location resolution/ticket.
- [ ] Reporting city, coordinates and capture timestamp are read-only and immutable after creation.
- [ ] Capture device/risk metadata and handle permission denied, service disabled, stale capture and provider errors.
- [ ] Support zero to five photos. Accident categories require a fresh camera primary image; eligible other categories may use camera/gallery or no image.
- [ ] Strip EXIF during normalized upload and keep evidence private until admin publication.
- [ ] Port safe structured rich-text features: paragraph, headings, bold/italic, lists, quote, links and undo/redo.
- [ ] Enforce headline/summary/body/source/tags/category/event-time rules and job-category/deadline behavior present in Ionic.
- [ ] Silently recover one unfinished new story per user plus route-scoped edit recovery; no public "Save draft" UI.
- [ ] Keep stable client UUIDs/upload paths so interrupted retries are idempotent.
- [ ] Final submission must call `submit_news_post` and confirm `pending`/`under_review` before showing success.

### P0 - News moderation and revisions

- [ ] Admin reviews reporter identity/rating/trust, private evidence, capture/submission times, map/GPS, risk flags, duplicate candidates and moderation history.
- [ ] Support publish, reject, request changes, under review, archive, remove and super-admin permanent delete with required reasons/notes.
- [ ] Publish only reviewed evidence through `moderate_news_with_media`; never expose private evidence directly.
- [ ] Normal reporters cannot self-assign breaking status; use the existing privileged action.
- [ ] Reporter sees exact moderation reason/note and can resubmit `changes_requested` content.
- [ ] Editing a published/corrected article creates a `pending_review` revision. The live version remains unchanged until `review_revision` approval.
- [ ] Approved correction shows badge, note, updated time and correction history.

### P1 - Public news experience

- [ ] Query only the safe `public_news` projection/search RPC, never private `news_posts` for public pages.
- [ ] Nearby/latest/trending/following/worldwide tabs with country, region, city, area, category, date, tag and text filters.
- [ ] Paging, pull/explicit refresh, cache/fallback, skeleton, empty, offline and retry states.
- [ ] News cards: images, headline, category, location, reporter/badge/rating, time, breaking/corrected, views/reactions/comments.
- [ ] Article gallery/body/source/byline/trust/statistics and safe city/area only; never public exact GPS.
- [ ] Job deadline/countdown/expired behavior from the Ionic shared job-deadline logic.
- [ ] Native/share links and deep-link routing.

### P1 - Engagement and community

- [ ] Like/dislike toggle with one reaction per user, self-reaction prevention and server constraints.
- [ ] Daily/session-throttled `record_view` behavior.
- [ ] Add/reply/delete comments, threaded rendering and comment reporting/moderation.
- [ ] Bookmark and saved stories.
- [ ] Follow reporter/city/area/category and following feed/list.
- [ ] Report news with controlled reasons and prevent duplicate active reports.
- [ ] Reporter leaderboard by city/country/global and configured period.
- [ ] Public reporter profile, stats, stories, follow and message actions.

### P1 - Verified member chat

- [x] Chat is allowed only when both accounts are active and have an approved identity verification; role alone is insufficient.
- [x] Username prefix search via `chat_people_search`, existing/new conversation open, inbox and peer deep link.
- [x] Cursor-paged message history, realtime changes and resync on reconnect/app resume plus visible periodic fallback.
- [x] Text only, 2,000-character maximum, stable retry message UUID and 30 messages/minute server limit.
- [x] Mark read/unread inbox counts, block/unblock in either direction and preserve readable history.
- [x] Member-side message reporting through `report_chat_message`.
- [x] Admin chat-report resolution supports investigating, dismissal, resolution and optional sender suspension.
- [x] Do not generate a duplicate notification for every chat message; migration 028 intentionally keeps chat updates in the inbox.

### P1 - Reporter dashboard, points and wallet

- [ ] Reporter stats, publication counts, views, likes, followers, rating and trust.
- [ ] Article analytics with owner enforcement and daily readership chart.
- [ ] Points total and auditable ledger; do not calculate or award points in Flutter.
- [ ] Wallet summary from `my_wallet_summary`: currency, available, pending, reserved, withdrawn, credited and minimum withdrawal.
- [ ] Withdrawal request with validated amount, payout method/details and reservation behavior.
- [ ] Admin transition rules: pending to approved/rejected, approved to paid/rejected; paid requires note and unique external payment reference.
- [ ] Only super admin can create audited wallet adjustments. Points must never be presented as guaranteed money.

### P1 - Account, notifications and privacy

- [ ] Edit profile and avatar with safe cleanup of the previous owned image.
- [ ] Notifications list/read state and deep links for moderation, appeals and wallet actions.
- [ ] Appeals for rejected/removed news and rejected verification.
- [ ] Request/cancel account deletion; do not silently delete legal/editorial records.
- [ ] Push-token register/unregister and device lifecycle only after confirming the deployed backend/function.
- [ ] Port privacy/data-safety behavior and ad-consent controls used by the Ionic app.

### P2 - Release and quality parity

- [ ] Android/iOS camera, photo picker, location permissions, app resume/back/keyboard behavior and recovery deep links.
- [ ] Connectivity-aware offline/retry behavior.
- [ ] Accessibility, dynamic text, keyboard/focus, contrast and screen-reader labels.
- [ ] Image compression/memory handling and list performance.
- [ ] Crash/error reporting strategy without sensitive identity/evidence leakage.
- [ ] Flutter unit/widget/integration tests for all role and state transitions.
- [ ] Live acceptance using separate reader, reporter, admin and super-admin accounts.
- [ ] Verify existing Play Store identity, signing, package name, privacy/data-safety disclosures and release behavior before replacing the live Ionic build.

## Existing backend contract to reuse

The old repository contains migrations `001_platform.sql` through `028_chat_without_notifications.sql`. Important existing contracts include:

- Safe views/projections: `public_news`, `public_reporters`, `reporter_statistics`.
- Auth/roles: `username_available`, `my_roles`, `is_reporter`, `is_admin`.
- Location: `location_cities`, deployed `resolve-location` Edge Function and server-side geocoded matching.
- Identity: `government_id_types`, `submit_identity`, `verification_context`, `audit_document_access`, `moderate_identity`.
- News/search: `search_news_global`, `submit_news_post`, `record_view`, moderation/revision/breaking/incident RPCs.
- Chat: `chat_eligible`, `chat_people_search`, `chat_open`, `chat_inbox`, `chat_send`, `chat_read`, `chat_block` and report RPCs.
- Economy: `leaderboard`, analytics RPCs, `my_wallet_summary`, `request_withdrawal`, `review_withdrawal`, wallet/points/trust adjustments.
- Governance/privacy: account actions, report/appeal resolution, account deletion requests, audit logs and contact queue.

Flutter repositories should wrap these contracts in typed domain/data layers. Do not scatter raw table/RPC strings through widgets, and do not weaken a database rule merely to make a screen work.

## Recommended implementation sequence

Each numbered item is a separate approval checkpoint. Do not start the next item without owner confirmation.

- [x] **1. Access-control foundation:** typed roles/account status, route map, auth/reporter/admin/super-admin guards, shell links and encoding fixes.
- [ ] **2. Signup/profile parity:** required country/city, metadata parity, editable profile/avatar and account status.
- [ ] **3. User identity verification:** private uploads, selfie, states, rejection/resubmission and appeal entry.
- [x] **4. Admin foundation + verification queue:** `/admin`, role-aware tabs, audited document review and approve/reject/suspend.
- [ ] **5. Live public feeds:** real news repository/cards, nearby/latest/trending/following/worldwide and filters.
- [x] **6. Article detail + engagement:** article, gallery, reactions, views, comments, bookmark, follow, share and reports.
- [x] **7. Reporter submission:** forced GPS, camera/gallery policy, editor, recovery, upload and idempotent review submission.
- [x] **8. My stories + news moderation:** reporter statuses/edit/resubmit plus admin news/evidence/duplicate review.
- [x] **9. Published revisions/corrections + article analytics.**
- [x] **10. Reporter dashboard, leaderboard, points and wallet/withdrawals.**
- [x] **11. Verified realtime chat + member-side message reports.**
- [x] **12. Remaining admin tabs:** reports, chat reports, appeals, users, deletions, withdrawals, categories, locations, settings, contact and audit.
- [ ] **13. Notifications and push lifecycle.** Legal/support, contact submission and Android advertising privacy controls are complete.
- [ ] **14. Native acceptance, security/regression testing and Play Store replacement checklist.**

## Definition of done for every approved item

- UI matches the current Flutter design system while preserving Ionic behavior.
- Live Supabase contract is verified without destructive database changes.
- Server permissions are respected and unauthorised paths are tested.
- Loading, empty, error, retry, offline and success states are present where relevant.
- Relevant unit/widget tests pass and static analysis completes.
- No credentials, raw identity data, private evidence URL or exact public GPS leaks into code/logs/UI.
- This checklist is updated with evidence (files/tests), then the owner is asked before the next item starts.

## Implementation progress - 2026-11-09

- Access checks now fail closed when roles/account status cannot be verified.
- Signup now requires and sends the existing `city_id` metadata contract.
- The user verification screen now supports country-specific ID types, private front/back uploads,
  a camera-only live selfie, status/reason display and rejected resubmission.
- The role-protected admin workspace and its audited verification review queue are live in Flutter;
  private evidence uses short signed URLs and decisions call `moderate_identity`.
- Home/latest/trending/worldwide/search now query `search_news_global` and render real public story
  cards with database categories, location scope, search and pagination.
- `/news/:slug` now loads the safe `public_news` article projection with gallery, structured body,
  correction history, view throttling, reactions, bookmarks, reporter follow, comments/replies,
  owner/admin comment deletion, story/comment reports and share-link copying.
- `/report-news` and `/report-news/edit/:id` now use the existing `categories`, `news_posts`,
  `news_media`, `news_revisions`, private `evidence` bucket, `resolve-location` report ticket and
  `submit_news_post` RPC. The Flutter client keeps the Ionic field names and status transitions,
  supports zero-to-five photos, requires camera evidence for accidents, silently restores local
  drafts, and uses stable UUID/upload paths for interrupted retries.
- `/my-stories` now reads the reporter's existing `news_posts`, excludes silent server drafts like
  Ionic, provides the same status/expired-job filters, displays exact moderation reasons/notes and
  creates news appeals through the existing `appeals` fields and RLS rules.
- The admin `news` tab now reviews private `news_media` through five-minute signed URLs, exact GPS,
  capture/device/risk context, reporter rating/trust/followers and `duplicate_candidates`. Decisions
  call `moderate_news_with_media`; reviewed images use stable `news-images/{post}/{media}.jpg` paths.
  Breaking changes, duplicate incident grouping and super-admin deletion use the existing audited RPCs.
- `/analytics/:id` now calls the owner/admin-protected `article_analytics` RPC for 7, 30 or 365 days
  and displays server-calculated views, verified views, reactions, comments, points and daily trends.
- The admin `revisions` tab now loads `news_revisions`, compares currently live and proposed content,
  enforces rejection reasons and calls `review_revision`. Approval is server-audited, changes the live
  article to `corrected` and feeds the existing public `correction_history`; pending revisions never
  alter public content.
- `/dashboard`, `/points`, `/wallet` and `/reporters` now use the unchanged `reporter_dashboard`,
  `leaderboard`, `my_wallet_summary` and `request_withdrawal` RPCs plus the existing reporter
  statistics, points, wallet transaction and withdrawal tables. Country/city/period ranking,
  performance, balance validation, bank payout details and history match Ionic.
- Added iOS camera/photo permission descriptions and a sanitized `config.example.json`.
- Implemented the account/profile/activity workspace: profile and independent home-city editing,
  normalized avatar replacement with safe cleanup, saved stories, following management/feed,
  comment history, verification appeals, appeal/report status history, password updates and the
  existing audited account-deletion request/cancellation flow.
- Connected canonical country, region, city and category feeds with slug validation, safe RPC
  filters, area/date/category controls, pagination and supported follow targets. Added the public
  reporter profile with public stats, published stories, follow state and chat entry point, and
  linked Explore, article bylines and leaderboard navigation to these live public routes.
- Added verified-member chat with eligibility enforcement, realtime and periodic inbox refresh,
  unread/read state, username search, direct reporter conversations, paged history, stable retry
  UUIDs, 2,000-character sending, block/unblock and member-side message reporting. Admin resolution
  is implemented in the admin chat-reports tab.
- Completed the remaining admin workspace with full queue overview, content/chat report resolution,
  appeal decisions, account and super-admin role/trust/points controls, read-only deletion review,
  withdrawal transitions and manual payment references, audited wallet adjustments, category/city
  creation, JSON settings, contact messages and audit history. It reuses the Ionic tables and RPCs,
  including `admin_payout_details`, `review_withdrawal`, `admin_account` and report/appeal resolvers.
- Ported the full Ionic English copy for all eight legal/about pages and replaced the public contact
  placeholder with validated, rate-limited `send_contact` submission. Signup agreements, account
  settings and desktop/mobile navigation now expose the relevant policies and newsroom contact page.
- This module was intentionally not built, analyzed or tested yet at the owner's request; final
  acceptance will be run after the remaining modules are complete.
- Remaining numbered items stay unchecked until their entire scope is implemented and verified.
- The earlier profile, appeal and following-scope code gaps are now implemented. Their numbered
  checkpoints remain unchecked until the owner's live acceptance is complete.

## Audit evidence inspected

Ionic: route map, guards, all feature components/templates, core backend/news/location/chat logic, requirements/user-flow/database/chat/offline-draft documentation, tests and Supabase migrations 001-028.  
Flutter: all `lib/**/*.dart`, routing/shell, auth, location, current tests, README and package configuration.

Static analysis was attempted during the audit but the local `flutter analyze`/`dart analyze` processes produced no result after more than a minute and were stopped. This audit therefore does not claim a clean analyzer run.
