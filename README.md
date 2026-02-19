# DeConnect — Supabase Backend

> Real-time chat + social feed backend powered by Supabase (Postgres, Edge Functions, Realtime)

This is the **complete Supabase backend** for DeConnect. Download it from GitHub and run it locally.


---

## Install Requirements

| Tool | Install |
|------|---------|
| Docker Desktop | [docker.com](https://www.docker.com/products/docker-desktop/) |
| Supabase CLI | [supabase.com/docs/guides/cli](https://supabase.com/docs/guides/cli/getting-started) |

---

## Run the Backend

Open terminal in this project folder and run these commands:

```bash
# Step 1: Start Supabase (first time takes 2-3 min to download Docker images)
supabase start

# Step 2: Create database (runs all 19 migrations + loads test data)
supabase db reset

# Step 3: Start edge functions
supabase functions serve --env-file .env
```

That's it! Your backend is running.

---

## What's Running Now

After the 3 commands above, you have:

| Service | URL | What It Does |
|---------|-----|--------------|
| **API** | http://localhost:54321 | Your app connects here |
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

## All Commands

### Everyday Commands

```bash
supabase start                       # Start backend
supabase stop                        # Stop backend
supabase status                      # Show URLs + keys
supabase db reset                    # Reset database (fresh start)
supabase functions serve --env-file .env   # Start edge functions
```

### View Logs

```bash
supabase logs                        # All logs
supabase logs db                     # Database only
supabase logs --follow               # Live tail
supabase functions logs send-push-notification   # Specific function
```

### Database

```bash
supabase db reset                    # Reset (runs all migrations + seed)
supabase db push                     # Push to production
supabase migration new my_feature    # Create new migration file
```

### Edge Functions

```bash
supabase functions serve --env-file .env                  # Run all locally
supabase functions new my-function                        # Create new function
supabase functions deploy send-push-notification          # Deploy one to production
```

### Secrets (for edge functions)

```bash
supabase secrets list                                     # Show all secrets
supabase secrets set FCM_SERVICE_ACCOUNT_JSON='...'       # Set Firebase key
supabase secrets set AGORA_APP_ID=xxx                     # Set Agora key
```

---

## Connect Your App

### Flutter

```dart
await Supabase.initialize(
  url: 'http://localhost:54321',
  anonKey: 'YOUR_ANON_KEY',  // get from: supabase status
);

// Login with test user
await Supabase.instance.client.auth.signInWithPassword(
  email: 'vathanak@test.com',
  password: 'password123',
);
```

### React / Next.js

```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'http://localhost:54321',
  'YOUR_ANON_KEY'  // get from: supabase status
)
```

> Run `supabase status` to get your `anon key`.

---

## Edge Functions Setup

The 8 edge functions run with `supabase functions serve --env-file .env`.

Some functions need API keys to fully work:

| Function | Needs | Why |
|----------|-------|-----|
| `send-push-notification` | Firebase key | Send push to phones |
| `create-post` | Nothing extra | Works out of the box |
| `send-message` | Nothing extra | Works out of the box |
| `moderate-content` | Nothing extra | Works out of the box |
| `admin-actions` | Nothing extra | Works out of the box |
| `cleanup-worker` | Nothing extra | Works out of the box |
| `group-links` | Nothing extra | Works out of the box |

### Add Firebase + Agora Keys (Optional)

Create `.env` file:

```bash
cp .env.example .env
```

Edit `.env`:

```env
FCM_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
AGORA_APP_ID=your_app_id
AGORA_APP_CERTIFICATE=your_certificate
```

Then set as secrets:

```bash
supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat .env | grep FCM_SERVICE_ACCOUNT_JSON | cut -d= -f2)"
supabase secrets set AGORA_APP_ID=your_app_id
supabase secrets set AGORA_APP_CERTIFICATE=your_certificate
```

### Push Notification DB Trigger

The database trigger that fires push notifications needs the service role key:

```bash
psql 'postgresql://postgres:postgres@localhost:54322/postgres' \
  -c "ALTER DATABASE postgres SET app.settings.service_role_key = 'YOUR_SERVICE_ROLE_KEY';"
```

Get `YOUR_SERVICE_ROLE_KEY` from `supabase status`.

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

# Admin actions (ban user)
curl -X POST http://localhost:54321/functions/v1/admin-actions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{"action":"ban_user","target_user_id":"b2222222-2222-2222-2222-222222222222"}'


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
| `profiles` | User accounts |
| `chat_rooms` | Group chats + DMs |
| `room_members` | Who's in which chat |
| `messages` | Chat messages |
| `posts` | Social feed posts |
| `comments` | Comments on posts (with replies) |
| `post_likes` | Like tracking |
| `notifications` | Push notification records |
| `user_devices` | Phones/tablets for multi-device push |
| `group_invite_links` | Group invite system |
| `system_logs` | Audit logs |
| `action_analytics` | Usage statistics |
| `calls` | Voice/video call records |
| `call_participants` | Call participation |
| `typing_indicators` | Real-time typing status |
| `post_image_deletions` | Image cleanup queue |

Full details: [ARCHITECTURE.md](ARCHITECTURE.md)

---

## Project Structure

```
deconnect-supabase/
├── supabase/
│   ├── config.toml              # Local settings
│   ├── seed.sql                 # Test data
│   ├── migrations/              # 19 SQL files (run in order)
│   └── functions/               # 8 Edge Functions
│       ├── _shared/             # Shared code (cors, supabase client, helpers)
│       ├── admin-actions/
│       ├── cleanup-worker/
│       ├── create-post/
│       ├── group-links/
│       ├── moderate-content/
│       ├── send-message/
│       └── send-push-notification/
├── ARCHITECTURE.md              # All tables, functions, policies
├── SETUP_GUIDE.md               # Dev workflow + deployment
├── CHANGELOG.md                 # Version history
└── README.md                    # This file
```

---

## Common Issues

| Problem | Fix |
|---------|-----|
| Docker not running | Open Docker Desktop, wait for green icon |
| Port already in use | `supabase stop` then `supabase start` |
| Can't find `supabase` command | Install CLI: [supabase.com/docs/guides/cli](https://supabase.com/docs/guides/cli/getting-started) |
| Migration failed | Check SQL syntax, then `supabase db reset` |
| Flutter can't connect | Run `supabase status`, copy the anon key |
| Edge function 404 | Make sure `supabase functions serve --env-file .env` is running |
| Push not working | Check `supabase secrets list` for Firebase key |

---

## Deploy to Production

See [SETUP_GUIDE.md](SETUP_GUIDE.md#deploy-to-production) for full steps.

Short version:

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
supabase functions deploy send-push-notification
supabase functions deploy admin-actions
# ... deploy each function
```

---

## More Documentation

| File | What's Inside |
|------|---------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | All tables, 50+ RPC functions, RLS policies, triggers |
| [SETUP_GUIDE.md](SETUP_GUIDE.md) | Dev workflow, making changes, deployment |
| [CHANGELOG.md](CHANGELOG.md) | Version history |
