# DeConnect — Supabase Backend

> Real-time chat + social feed backend powered by Supabase (Postgres, Edge Functions, Realtime)

This is the **complete Supabase backend** for DeConnect. Download it from GitHub and run it locally.

---


## Install Requirements

| Tool | Install |
|------|---------|
| Docker Desktop | [docker.com](https://www.docker.com/products/docker-desktop/) |
| Supabase CLI | [supabase.com/docs/guides/cli](https://supabase.com/docs/guides/cli/getting-started) |
| ngrok | [ngrok.com/download](https://ngrok.com/download) |

> Supabase CLI handles Deno for edge functions — no separate Deno install needed.

---

## Run the Backend

You need **3 terminals** running at the same time:

```bash
# Terminal 1 — Start Supabase (first time takes 2-3 min to download Docker images)
supabase start
supabase db reset    # Creates database with all 18 migrations + test data

# Terminal 2 — Start edge functions
supabase functions serve --env-file .env

# Terminal 3 — Start ngrok (makes your backend reachable from physical phones)
ngrok http 54321
```

ngrok will show a public URL like `https://abc123.ngrok-free.app`.

| Testing on | Use this URL |
|------------|-------------|
| Emulator / Simulator | `http://localhost:54321` |
| Physical phone (APK) | `https://abc123.ngrok-free.app` (from ngrok output) |

---

## What's Running Now

After the 3 terminals above, you have:

| Service | URL | What It Does |
|---------|-----|--------------|
| **API (local)** | http://localhost:54321 | For emulator/simulator |
| **API (ngrok)** | https://abc123.ngrok-free.app | For physical phone |
| **Studio** | http://localhost:54323 | Visual database editor (open in browser!) |
| **Edge Functions** | http://localhost:54321/functions/v1/ | 8 serverless functions |
| **Database** | postgresql://postgres:postgres@localhost:54322/postgres | PostgreSQL direct access |

Open **http://localhost:54323** in your browser to see your database.

---

## Test Users

All passwords are `password123`:

| Email | Username | Role |
|-------|----------|------|
| vathanak@test.com | vathanak | user |
| Sak@test.com | Sak | user |
| dara@test.com | sovandara | **admin** |

---

## Connect Your App

### Flutter (Emulator / Simulator)

```dart
await Supabase.initialize(
  url: 'http://localhost:54321',
  anonKey: 'YOUR_ANON_KEY',  // get from: supabase status
);
```

### Flutter (Physical Device / APK)

```dart
await Supabase.initialize(
  url: 'https://abc123.ngrok-free.app',  // your ngrok URL from Terminal 3
  anonKey: 'YOUR_ANON_KEY',               // same key from: supabase status
);
```

> The ngrok URL **changes every time** you restart ngrok. Update your Flutter config each time, or use a static domain with ngrok paid plan: `ngrok http 54321 --domain=your-app.ngrok.app`

### React / Next.js

```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'http://localhost:54321',     // or ngrok URL for physical device
  'YOUR_ANON_KEY'               // get from: supabase status
)
```

> Run `supabase status` to get your `anon key` and `service_role key`.

---

## ngrok Setup (First Time Only)

### 1. Install

```bash
# macOS
brew install ngrok

# Or download from https://ngrok.com/download
```

### 2. Authenticate

Create a free account at [ngrok.com](https://ngrok.com), then:

```bash
ngrok authtoken YOUR_AUTH_TOKEN
```

Get your auth token from the [ngrok dashboard](https://dashboard.ngrok.com/get-started/your-authtoken).

### 3. Done

Now `ngrok http 54321` works. You only need to do steps 1–2 once.

---

## Edge Functions Setup

Edge functions run with `supabase functions serve --env-file .env`.

### Create the .env file

```bash
cp .env.example .env
```

If `.env.example` doesn't exist, create `.env` manually:

```env
# Required for push notifications (Firebase)
FCM_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"...","private_key":"...","client_email":"..."}'

# Required for video/voice calls (Agora)
AGORA_APP_ID=your_agora_app_id
AGORA_APP_CERTIFICATE=your_agora_certificate
```

### Which functions need API keys?

| Function | Needs | Why |
|----------|-------|-----|
| `send-push-notification` | Firebase key | Send push to phones |
| `agora-token` | Agora keys | Video/voice calls |
| `create-post` | Nothing extra | Works out of the box |
| `send-message` | Nothing extra | Works out of the box |
| `moderate-content` | Nothing extra | Works out of the box |
| `admin-actions` | Nothing extra | Works out of the box |
| `cleanup-worker` | Nothing extra | Works out of the box |
| `group-links` | Nothing extra | Works out of the box |

> 6 of 8 functions work without any API keys. Only push notifications and video calls need credentials.

### Set secrets (for production or local testing)

```bash
supabase secrets set FCM_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
supabase secrets set AGORA_APP_ID=your_app_id
supabase secrets set AGORA_APP_CERTIFICATE=your_certificate
```

### Push notification DB trigger

The database trigger that fires push notifications needs the service role key:

```bash
psql 'postgresql://postgres:postgres@localhost:54322/postgres' \
  -c "ALTER DATABASE postgres SET app.settings.service_role_key = 'YOUR_SERVICE_ROLE_KEY';"
```

Get `YOUR_SERVICE_ROLE_KEY` from `supabase status`.

---

## All CLI Commands

### Everyday (3 Terminals)

```bash
# Terminal 1
supabase start                             # Start backend
supabase db reset                          # Reset database (fresh start)

# Terminal 2
supabase functions serve --env-file .env   # Start edge functions

# Terminal 3
ngrok http 54321                           # Tunnel for physical device
```

### Stop Everything

```bash
supabase stop                              # Stop Supabase (Terminal 1)
# Ctrl+C in Terminal 2 to stop edge functions
# Ctrl+C in Terminal 3 to stop ngrok
```

### Database

```bash
supabase db reset                          # Reset (runs all migrations + seed)
supabase db push                           # Push to production
supabase db diff                           # Show changes vs production
supabase migration new my_feature          # Create new migration file
```

### Edge Functions

```bash
supabase functions serve --env-file .env                  # Run all locally
supabase functions new my-function                        # Create new function
supabase functions deploy send-push-notification          # Deploy one to production
```

### Secrets

```bash
supabase secrets list                                     # Show all secrets
supabase secrets set KEY=value                            # Set a secret
supabase secrets unset KEY                                # Remove a secret
```

### Logs

```bash
supabase logs                              # All logs
supabase logs db                           # Database only
supabase logs --follow                     # Live tail
```

### ngrok

```bash
ngrok http 54321                           # Tunnel Supabase API
ngrok http 54321 --domain=your.ngrok.app   # Use static domain (paid plan)
```

### Direct Database Access

```bash
psql postgresql://postgres:postgres@localhost:54322/postgres
```

---

## Test Edge Functions

Get your keys first: `supabase status`

```bash
# Push notification
curl -X POST http://localhost:54321/functions/v1/send-push-notification \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -d '{"user_id":"a1111111-1111-1111-1111-111111111111","title":"Test","body":"Hello","channel":"general"}'

# Create post
curl -X POST http://localhost:54321/functions/v1/create-post \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{"title":"My Post","content":"Hello world","tags":["test"]}'

# Admin actions (ban user — must be logged in as admin)
curl -X POST http://localhost:54321/functions/v1/admin-actions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{"action":"ban_user","target_user_id":"b2222222-2222-2222-2222-222222222222"}'

# Agora token (video call)
curl -X POST http://localhost:54321/functions/v1/agora-token \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{"channel_name":"test-call"}'

# Moderate content
curl -X POST http://localhost:54321/functions/v1/moderate-content \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{"text":"some text to check"}'

# Group links
curl -X POST http://localhost:54321/functions/v1/group-links \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{"action":"generate","room_id":"d4444444-4444-4444-4444-444444444444"}'

# Cleanup worker
curl -X POST http://localhost:54321/functions/v1/cleanup-worker \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY"

# Send message
curl -X POST http://localhost:54321/functions/v1/send-message \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{"room_id":"d4444444-4444-4444-4444-444444444444","content":"Hello!"}'
```

---

## Database Tables (16)

| Table | What It Stores |
|-------|----------------|
| `profiles` | User accounts (username, avatar, role, online status, bio) |
| `chat_rooms` | Group chats + DMs (name, invite code, max members) |
| `room_members` | Who's in which chat (admin status, join date) |
| `messages` | Chat messages (content, media, read status, replies) |
| `posts` | Social feed posts (title, content, image, tags) |
| `comments` | Comments on posts (with reply support) |
| `post_likes` | Like tracking (unique per user+post) |
| `notifications` | Push notification records (channel, read status) |
| `user_devices` | Phones/tablets for multi-device push (FCM token, current room) |
| `group_invite_links` | Group invite system (code, expiry, max uses) |
| `calls` | Voice/video call records (caller, callee, status, duration) |
| `call_participants` | Call participation (join/leave times) |
| `typing_indicators` | Real-time typing status |
| `system_logs` | Audit logs (level, feature, action, metadata) |
| `action_analytics` | Usage statistics |
| `post_image_deletions` | Image cleanup queue (processed flag) |

---

## Storage Buckets (5)

| Bucket | Purpose | Max Size |
|--------|---------|----------|
| `avatars` | User profile images | 5 MB |
| `post-images` | Social feed post images | 8 MB |
| `chat-images` | Chat image attachments | 150 MB |
| `chat-media` | Chat media (video, audio, docs) | 50 MB |
| `chat-files` | Chat file attachments | 150 MB |

---

## Project Structure

```
deconnect-supabase/
├── supabase/
│   ├── config.toml              # Local settings (ports, auth, functions)
│   ├── seed.sql                 # Test data (3 users, 1 chat, 2 posts, 5 buckets)
│   ├── migrations/              # 18 SQL files (run in order)
│   │   ├── 20260209000001_extensions.sql
│   │   ├── 20260209000002_tables.sql
│   │   ├── 20260209000003_indexes.sql
│   │   ├── 20260209000004_triggers_helpers.sql
│   │   ├── 20260209000005_rpc_functions.sql
│   │   ├── 20260209000006_rls_policies.sql
│   │   ├── 20260209000007_storage_policies.sql
│   │   ├── 20260209000008_cleanup_post_images.sql
│   │   ├── 20260209000009_add_image_path_to_posts.sql
│   │   ├── 20260213000010_push_notifications.sql
│   │   ├── 20260213000011_push_notification_rpcs.sql
│   │   ├── 20260213000013_logsystem.sql
│   │   ├── 20260217000001_post_comment_notifications.sql
│   │   ├── 20260217000002_consolidated_notification_fixes.sql
│   │   ├── 20260218000001_user_devices.sql
│   │   ├── 20260218000002_fix_type_field_triggers.sql
│   │   ├── 20260218100000_fixes.sql
│   │   └── 20260218200000_comprehensive_fixes.sql
│   └── functions/               # 8 Edge Functions
│       ├── _shared/             # Shared code (cors.ts, supabase.ts, helpers.ts)
│       ├── admin-actions/
│       ├── agora-token/
│       ├── cleanup-worker/
│       ├── create-post/
│       ├── group-links/
│       ├── moderate-content/
│       ├── send-message/
│       └── send-push-notification/
├── .env.example                 # Template for environment variables
├── ARCHITECTURE.md              # All tables, functions, policies, triggers
├── SETUP_GUIDE.md               # Dev workflow + deployment
├── CHANGELOG.md                 # Version history
└── README.md                    # This file
```

---

## Common Issues

| Problem | Fix |
|---------|-----|
| Docker not running | Open Docker Desktop, wait for green whale icon |
| Port already in use | `supabase stop` then `supabase start` |
| Can't find `supabase` command | Install CLI: [supabase.com/docs/guides/cli](https://supabase.com/docs/guides/cli/getting-started) |
| Migration failed | Check SQL syntax, then `supabase db reset` |
| Flutter can't connect (emulator) | Run `supabase status`, copy the anon key |
| Flutter can't connect (physical device) | Check ngrok is running, use the ngrok URL in Flutter |
| Edge function 404 | Make sure Terminal 2 is running `supabase functions serve --env-file .env` |
| Push not working | Check `supabase secrets list` for Firebase key |
| Database out of sync | `supabase db reset` reapplies everything from scratch |
| ngrok URL changed | Restart `ngrok http 54321`, update Flutter config with new URL |

---

## Deploy to Production

See [SETUP_GUIDE.md](SETUP_GUIDE.md#deploy-to-production) for full steps.

Quick version:

```bash
# 1. Link to your Supabase cloud project
supabase link --project-ref YOUR_PROJECT_REF

# 2. Push database
supabase db push

# 3. Deploy edge functions
for func in supabase/functions/*/; do
  fname=$(basename "$func")
  [ "$fname" = "_shared" ] && continue
  supabase functions deploy "$fname"
done

# 4. Set production secrets
supabase secrets set FCM_SERVICE_ACCOUNT_JSON='...'
supabase secrets set AGORA_APP_ID=your_app_id
supabase secrets set AGORA_APP_CERTIFICATE=your_certificate

# 5. Update Flutter config
# Change url to https://YOUR_PROJECT_REF.supabase.co
# Change anonKey to your production anon key (from Supabase Dashboard → Settings → API)
```

> In production, you don't need ngrok — Supabase cloud gives you a public URL.

---

## More Documentation

| File | What's Inside |
|------|---------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | All 16 tables, 50+ RPC functions, RLS policies, triggers, relationships |
| [SETUP_GUIDE.md](SETUP_GUIDE.md) | Dev workflow, ngrok setup, making changes, deployment |
| [CHANGELOG.md](CHANGELOG.md) | Version history with exact stats per release |
