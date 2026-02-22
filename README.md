# DeConnect — Supabase Backend

> Real-time chat + social feed backend powered by Supabase (Postgres, Edge Functions, Realtime)

This is the **complete Supabase backend** for the DeConnect Flutter app. Clone it from GitHub and run it locally.

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Docker Desktop | Latest | [docker.com](https://www.docker.com/products/docker-desktop/) |
| Supabase CLI | >= 1.100 | `brew install supabase/tap/supabase` or [docs](https://supabase.com/docs/guides/cli/getting-started) |
| Node.js | >= 18 | [nodejs.org](https://nodejs.org/) (required for edge functions) |

---

## Quick Start

Open a terminal in this project folder and run:

```bash
# 1. Start Supabase (first time takes 2-3 min to pull Docker images)
supabase start

# 2. Set up the .env file
cp .env.example .env
# Edit .env with your Firebase service account JSON (optional for push notifications)

# 3. Create database (runs all 18 migrations + loads seed data)
supabase db reset

# 4. Start edge functions
supabase functions serve --env-file .env
```

Your backend is now running!

---

## What's Running

After the commands above, these services are available:

| Service | URL | Description |
|---------|-----|-------------|
| **API Gateway** | http://localhost:54321 | REST + Realtime API (app connects here) |
| **Studio** | http://localhost:54323 | Visual database editor (open in browser) |
| **Auth** | http://localhost:54321/auth/v1 | Authentication endpoints |
| **Edge Functions** | http://localhost:54321/functions/v1/ | 8 serverless functions |
| **Inbucket** | http://localhost:54324 | Email testing inbox |
| **Database** | postgresql://postgres:postgres@localhost:54322/postgres | Direct PostgreSQL access |

> Run `supabase status` to see all URLs and API keys.

---

## Test Users (from seed data)

All passwords are `password123`:

| Email | Username | Role |
|-------|----------|------|
| vathanak@test.com | vathanak | user |
| Sak@test.com | Sak | user |
| dara@test.com | sovandara | **admin** |

---

## CLI Commands Reference

### Startup & Shutdown

```bash
supabase start                              # Start all services
supabase stop                               # Stop all services
supabase stop --no-backup                   # Stop and remove all data
supabase status                             # Show URLs + API keys
```

### Database

```bash
supabase db reset                           # Drop & recreate DB (migrations + seed)
supabase db push                            # Push migrations to remote/production
supabase migration new my_feature           # Create a new migration file
supabase migration list                     # List all migrations
```

### Edge Functions

```bash
supabase functions serve --env-file .env    # Run all functions locally
supabase functions new my-function          # Create a new function
supabase functions deploy <function-name>   # Deploy a single function to production
```

### Logs

```bash
supabase logs                               # View all logs
supabase logs db                            # Database logs only
supabase logs --follow                      # Live tail
supabase functions logs <function-name>     # Specific function logs
```

### Secrets (production)

```bash
supabase secrets list                       # List all secrets
supabase secrets set KEY=value              # Set a secret
supabase secrets unset KEY                  # Remove a secret
```

---

## Flutter App Connection

The Flutter app uses `.env.dev` with:

```env
SUPABASE_URL=http://10.0.2.2:54321
SUPABASE_ANON_KEY=<anon key from supabase status>
```

- **Android Emulator:** Uses `10.0.2.2` to reach host's `localhost`
- **iOS Simulator / macOS:** Uses `127.0.0.1` directly
- **Physical Device:** Use your Mac's LAN IP (e.g., `192.168.x.x:54321`)

> The `EnvConfig` class in the Flutter app auto-adapts the URL per platform.

---

## Edge Functions

8 edge functions (+ 1 shared module):

| Function | Auth Required | Description |
|----------|---------------|-------------|
| `send-push-notification` | Service Role | Send FCM push notifications |
| `create-post` | Anon/User | Create social feed posts |
| `send-message` | Anon/User | Send chat messages |
| `moderate-content` | Anon/User | Content moderation checks |
| `admin-actions` | Anon/User | Admin operations (ban, unban, etc.) |
| `cleanup-worker` | Service Role | Clean up expired data |
| `group-links` | Anon/User | Generate/validate group invite links |
| `agora-token` | Anon/User | Generate Agora tokens for voice/video calls |

### Environment Variables

Create `.env` from the example:

```bash
cp .env.example .env
```

Required variables in `.env`:

```env
# Supabase (get values from `supabase status`)
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=<from supabase status>
SUPABASE_SERVICE_ROLE_KEY=<from supabase status>

# Firebase Push Notifications (optional — only for send-push-notification)
FCM_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'

# Agora Voice/Video (optional — only for agora-token)
AGORA_APP_ID=your_app_id
AGORA_APP_CERTIFICATE=your_certificate
```

---

## Database Schema (16 tables)

| Table | Description |
|-------|-------------|
| `profiles` | User profiles (auto-created on signup via trigger) |
| `chat_rooms` | Group chats + direct messages |
| `room_members` | Chat room membership |
| `messages` | Chat messages (text + file) |
| `posts` | Social feed posts |
| `comments` | Comments on posts (supports replies) |
| `post_likes` | Post like tracking |
| `notifications` | Push notification records |
| `user_devices` | Device registration for multi-device push |
| `group_invite_links` | Group invite code system |
| `system_logs` | Audit trail |
| `action_analytics` | Usage analytics |
| `calls` | Voice/video call records |
| `call_participants` | Call participation tracking |
| `typing_indicators` | Real-time typing status |
| `post_image_deletions` | Image cleanup queue |

Full schema details: [ARCHITECTURE.md](ARCHITECTURE.md)

---

## Project Structure

```
deconnect-supabase-local/
├── .env.example                 # Template for environment variables
├── .gitignore                   # Git ignore rules
├── README.md                    # This file
├── ARCHITECTURE.md              # Full schema, RPC functions, RLS policies
├── SETUP_GUIDE.md               # Dev workflow + deployment guide
├── CHANGELOG.md                 # Version history
├── package.json                 # Node.js dependencies
└── supabase/
    ├── config.toml              # Supabase local configuration
    ├── seed.sql                 # Test data (3 users, sample posts, chats)
    ├── migrations/              # 18 SQL migration files (run in order)
    │   ├── 20260209000001_extensions.sql
    │   ├── 20260209000002_tables.sql
    │   ├── 20260209000003_indexes.sql
    │   ├── 20260209000004_triggers_helpers.sql
    │   ├── 20260209000005_rpc_functions.sql
    │   ├── 20260209000006_rls_policies.sql
    │   ├── 20260209000007_storage_policies.sql
    │   ├── 20260209000008_cleanup_post_images.sql
    │   ├── 20260209000009_add_image_path_to_posts.sql
    │   ├── 20260213000010_push_notifications.sql
    │   ├── 20260213000011_push_notification_rpcs.sql
    │   ├── 20260213000013_logsystem.sql
    │   ├── 20260217000001_post_comment_notifications.sql
    │   ├── 20260217000002_consolidated_notification_fixes.sql
    │   ├── 20260218000001_user_devices.sql
    │   ├── 20260218000002_fix_type_field_triggers.sql
    │   ├── 20260218100000_fixes.sql
    │   └── 20260218200000_comprehensive_fixes.sql
    └── functions/               # 8 Edge Functions + shared module
        ├── _shared/             # Shared utilities (CORS, Supabase client)
        ├── admin-actions/
        ├── agora-token/
        ├── cleanup-worker/
        ├── create-post/
        ├── group-links/
        ├── moderate-content/
        ├── send-message/
        └── send-push-notification/
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Docker not running | Open Docker Desktop, wait for the green icon |
| Port already in use | `supabase stop` then `supabase start` |
| `supabase` command not found | Install: `brew install supabase/tap/supabase` |
| Migration failed | Check SQL syntax, then `supabase db reset` |
| Flutter can't connect (emulator) | Ensure `usesCleartextTraffic="true"` in AndroidManifest.xml |
| Flutter can't connect (physical device) | Use Mac's LAN IP instead of `10.0.2.2` in `.env.dev` |
| Edge function returns 404 | Ensure `supabase functions serve --env-file .env` is running |
| Push notifications not working | Check `.env` has valid `FCM_SERVICE_ACCOUNT_JSON` |
| Login/register stuck loading | Verify Supabase is running: `curl http://localhost:54321/auth/v1/health` |

---

## Deploy to Production

See [SETUP_GUIDE.md](SETUP_GUIDE.md#deploy-to-production) for full steps.

```bash
# 1. Link to your Supabase project
supabase link --project-ref YOUR_PROJECT_REF

# 2. Push database schema
supabase db push

# 3. Deploy all edge functions
supabase functions deploy send-push-notification
supabase functions deploy create-post
supabase functions deploy send-message
supabase functions deploy moderate-content
supabase functions deploy admin-actions
supabase functions deploy cleanup-worker
supabase functions deploy group-links
supabase functions deploy agora-token

# 4. Set production secrets
supabase secrets set FCM_SERVICE_ACCOUNT_JSON='...'
supabase secrets set AGORA_APP_ID=your_app_id
supabase secrets set AGORA_APP_CERTIFICATE=your_certificate
```

---

## More Documentation

| File | Contents |
|------|----------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Full schema, 50+ RPC functions, RLS policies, triggers |
| [SETUP_GUIDE.md](SETUP_GUIDE.md) | Development workflow, making changes, deployment |
| [CHANGELOG.md](CHANGELOG.md) | Version history |
