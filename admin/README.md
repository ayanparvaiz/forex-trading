# Forex Social Admin

The admin panel: a Next.js app, exported as static files and hosted on
Firebase Hosting at https://forex-social-admin.web.app.

| Section | What an admin can do |
|---|---|
| Dashboard | Counts, fourteen days of sign-ups and posts, newest people, open reports |
| Users | Search, filter (ranked, banned), sort; one person's scores, posts and reports; ban, lift a ban, delete the account |
| Reports | Open, resolved, dismissed; delete what was reported, remove it, ban, or settle it |
| Feed | Every post in Global and the communities, with comments; delete either |
| Communities | Members, rules, events; lock, unlock, remove a member, delete the community |
| Chat rooms | Global and each community's chat; remove a message |
| Leaderboard | All time, this week, the community ranking and its champions |
| Announcements | One notification to every phone, in Bangla and English |

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
python3 tool/make_admin.py <username>            # make someone an admin
python3 tool/make_admin.py <username> --remove   # and undo it
python3 tool/make_admin.py --list
```

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
