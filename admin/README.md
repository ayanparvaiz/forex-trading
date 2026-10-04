# Forex Social Admin

The admin panel: a Next.js app, exported as static files and hosted on
Firebase Hosting at https://forex-social-admin.web.app.

| Section | What it does |
|---|---|
| Dashboard | Counts; who used the app right now, today, this week, this month; growth over 30 or 90 days (accounts, daily active, closed trades); fourteen days of sign-ups and posts; newest people; open reports |
| Users | Search, filter, sort, export to CSV; one person's scores, posts, reports and admin history; warn, set a new password, fix a name or picture, ban for 1/3/7/30 days or for good (optionally removing everything they posted), remove everything they posted, lift a ban, delete the account |
| Reports | Open, resolved, dismissed — counted live in the sidebar; delete what was reported, remove it, ban, settle it; posts hidden for reports shown again; report alerts on your phone, on or off; export |
| Feed | Every post in Global and the communities, with comments; delete either; pin a Global post above the rest; posts hidden for reports shown again |
| Chat rooms | Global and each community's chat; remove a message |
| Help inbox | Messages people write to the admins in the app, answered (the answer reaches their phone) or put away; requests from people locked out, with the new password set from there |
| Communities | Members, rules, events; edit the name, about, rules and slow mode; make a member its admin; plan or take down an event; lock, unlock, remove a member, delete |
| Leaderboard | All time, this week, the community ranking and its champions; export |
| Announcements | One notification to every phone or one community, in Bangla and English — now, or scheduled; cancel what is waiting |
| App settings | Maintenance; a banner across the app; force an update; switches for Global chat, community chats, posting, comments and private chats; how many reports hide a post; the pinned post |
| Blocked words | Words and links nobody can post — the Firestore rules refuse them, and the app says why |
| Admins | Owners, admins and moderators; add by username, change a role, remove |
| Activity | Every change, by whom, to whom, when — including what the worker did on its own; nobody can edit it; export |
| Backup | Everything the panel can read, in one JSON file |

**Roles.** Owners are set up by hand (`tool/make_admin.py`) and can only be
removed that way. Admins can do everything in the panel. Moderators look after
posts, comments, chat messages and reports: they remove them, warn people, fix
a name or picture and ban for up to a week; they don't see the help inbox,
settings, announcements, admins or backups. The worker enforces this; the
panel only hides what it would refuse.

**On its own.** Every quarter hour the worker lifts bans whose time is up,
sends scheduled announcements, tells admins' phones about new reports,
messages and password requests, and takes a post off the feeds once enough
different people report it. Each morning it keeps the day's numbers for the
growth chart. The panel signs out after 30 minutes with nothing done.

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
