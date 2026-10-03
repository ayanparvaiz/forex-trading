# Forex Social Admin

The admin panel: a Next.js app, exported as static files and hosted on
Firebase Hosting at https://forex-social-admin.web.app.

| Section | What an admin can do |
|---|---|
| Dashboard | Counts; who used the app right now, today, this week, this month; fourteen days of sign-ups and posts; newest people; open reports |
| Users | Search, filter (ranked, banned), sort, export to CSV; one person's scores, posts, reports and admin history; warn, set a new password, fix a name or picture, ban for 1/3/7/30 days or for good, lift a ban, delete the account |
| Reports | Open, resolved, dismissed — counted live in the sidebar; delete what was reported, remove it, ban, or settle it; export |
| Feed | Every post in Global and the communities, with comments; delete either; pin a Global post above the rest |
| Chat rooms | Global and each community's chat; remove a message |
| Communities | Members, rules, events; edit the name, about, rules and slow mode; make a member its admin; lock, unlock, remove a member, delete |
| Leaderboard | All time, this week, the community ranking and its champions; export |
| Announcements | One notification to every phone, or to one community's members, in Bangla and English |
| App settings | Close the app for maintenance; a banner across the app; force an update; the pinned post |
| Blocked words | Words and links nobody can post — the Firestore rules refuse them, and the app says why |
| Admins | Who can use the panel; add by username, remove |
| Activity | Every change any admin made, by whom, to whom, when; nobody can edit it; export |

Private messages between two people are never shown here.

## How it fits together

- **Reading** happens in the browser with the Firebase JS SDK. The Firestore
  rules let anyone listed under `admins/{uid}` read what the panel shows.
- **Every change** goes through the worker (`POST /admin` in
  `worker/src/admin.js`), which checks `admins/{uid}` before doing anything.
  The rules never let an admin write directly.
- Admins sign in with their app username and password.

## Admins

```bash
python3 tool/make_admin.py <username>            # make someone an owner
python3 tool/make_admin.py <username> --remove   # and undo it
python3 tool/make_admin.py --list
```

Admins made this way are **owners**: the panel can add and remove other
admins, but never an owner, so nobody added in the panel can lock out the
people who added them.

## What the app follows

`config/app` (maintenance, the oldest build allowed, a banner, the pinned
post) and `config/moderation` (blocked words) are written only by the
worker and read by every phone, live. Before each release, raise the build
in `app/pubspec.yaml` (`version: x.y.z+N`) and `app/lib/core/build_info.dart`
together — a test fails if they differ. The panel reads the build from
`app/pubspec.yaml` when it is built, so after a release, rebuild and deploy
it; “Force an update” can then stop older builds.

## Running and deploying

```bash
cd admin
npm install
npm run dev                      # http://localhost:3000

npx next build                   # writes out/
cd .. && npx firebase-tools deploy --only hosting --project forex-9f21b
```

The worker accepts requests from the hosted panel and from
`http://localhost:3000` only.
