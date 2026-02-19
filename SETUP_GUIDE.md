# Setup & Development Guide

Complete guide for developing with DeConnect Supabase backend.

---

## First Time Setup

Already done `supabase start`? Skip to [Daily Workflow](#daily-workflow).

### 1. Install Tools

- **Docker Desktop** — [docker.com](https://www.docker.com/products/docker-desktop/)
- **Supabase CLI** — [supabase.com/docs/guides/cli](https://supabase.com/docs/guides/cli/getting-started)

### 2. Start Supabase

```bash
cd deconnect-supabase
supabase start
```

Save the output (API URL, anon key, service_role key).

### 3. Create Database

```bash
supabase db reset
```

Done! Database is ready with 16 tables + test data.

---

## Daily Workflow

### Start Working

```bash
supabase start          # Start services
open http://localhost:54323   # Open Studio
```

### Stop Working

```bash
supabase stop           # Stop all services
```

### See What's Running

```bash
supabase status
```

---

## Making Changes

### Modify Database

Edit the migration file for what you want to change:

| What to Change | Edit This File |
|----------------|----------------|
| Add/modify a table | `supabase/migrations/20260209000002_tables.sql` |
| Add an index | `supabase/migrations/20260209000003_indexes.sql` |
| Add a trigger | `supabase/migrations/20260209000004_triggers_helpers.sql` |
| Add an RPC function | `supabase/migrations/20260209000005_rpc_functions.sql` |
| Change security | `supabase/migrations/20260209000006_rls_policies.sql` |

Then apply your changes:

```bash
supabase db reset     # Recreate database with your changes
```

### Create New Migration

For big new features:

```bash
supabase migration new my_feature_name
```

Edit the new file in `supabase/migrations/`, then:

```bash
supabase db reset
```

---

## Testing

### Test with Supabase Studio

http://localhost:54323

- **Table Editor** → View/edit data
- **SQL Editor** → Run queries
- **Database → Functions** → Test RPC functions

### Test with psql

```bash
psql postgresql://postgres:postgres@localhost:54322/postgres

-- Example: Check users
SELECT * FROM profiles;

-- Example: Call RPC
SELECT get_user_chat_rooms();
```

---

## Edge Functions

Edge functions need Firebase (push notifications) and Agora (video calls).

### Setup Secrets (One Time)

Create `.env`:

```bash
cp .env.example .env
```

Edit `.env` and add your keys. Then:

```bash
supabase secrets set FCM_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'

```

### Run Edge Functions

```bash
supabase functions serve --env-file .env
```

Functions available at http://localhost:54321/functions/v1/

### Test Edge Functions

```bash
# Test push notification
curl -X POST http://localhost:54321/functions/v1/send-push-notification \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -d '{"user_id": "a1111111-1111-1111-1111-111111111111", "title": "Test", "body": "Hello", "channel": "general"}'

# Test create post
curl -X POST http://localhost:54321/functions/v1/create-post \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{"title": "My Post", "content": "Hello world", "tags": ["test"]}'
```

Get your keys from `supabase status`.

---

## Deploy to Production

### 1. Create Supabase Project

Go to [supabase.com](https://supabase.com) → Create new project.

### 2. Link Your Local Project

```bash
supabase link --project-ref YOUR_PROJECT_REF
```

Find your project ref in Supabase dashboard URL: `supabase.com/project/YOUR_PROJECT_REF`

### 3. Push Database

```bash
supabase db push
```

This runs all 19 migrations on your production database.

### 4. Deploy Edge Functions

```bash
# Deploy all functions
for func in supabase/functions/*/; do
  fname=$(basename "$func")
  [ "$fname" = "_shared" ] && continue
  supabase functions deploy "$fname"
done
```

Or deploy one at a time:

```bash
supabase functions deploy send-push-notification
```

### 5. Set Production Secrets

```bash
supabase secrets set FCM_SERVICE_ACCOUNT_JSON='...'
supabase secrets set AGORA_APP_ID=your_app_id
supabase secrets set AGORA_APP_CERTIFICATE=your_certificate
```

### 6. Update Your App

```dart
// Change from localhost to production
static const String supabaseUrl = 'https://YOUR_PROJECT_REF.supabase.co';
static const String supabaseAnonKey = 'YOUR_PRODUCTION_ANON_KEY';
```

Find your production keys: Supabase Dashboard → Settings → API

---

## Troubleshooting

### Can't Start Supabase

**Error:** Port already in use

```bash
supabase stop
supabase start
```

**Error:** Docker not running

1. Open Docker Desktop
2. Wait for green icon
3. `supabase start`

### Database Issues

**Error:** Migration failed

Check the SQL syntax in the failing file, then:

```bash
supabase db reset
```

**RLS blocks my query**

Expected! Users can only access their own data. Make sure:
1. User is logged in
2. Querying their own data

### Edge Function Issues

**Error:** Function returns 404

```bash
supabase functions serve --env-file .env
```

Check the function name matches the directory name.

**Error:** Push notifications don't work

1. Check secrets: `supabase secrets list`
2. Verify FCM_SERVICE_ACCOUNT_JSON is set
3. Check user registered device: `SELECT * FROM user_devices;`

### Flutter Connection Issues

Make sure these match:

```dart
// In Flutter
url: 'http://localhost:54321'
anonKey: 'ey...'  // Get from: supabase status
```

```bash
# Check your local values
supabase status
```

---

## Useful Commands

### Database

```bash
supabase db reset                    # Fresh database (runs all migrations)
supabase db push                     # Push to production
supabase db diff                     # Show changes vs production
supabase migration new my_feature    # Create new migration
```

### Edge Functions

```bash
supabase functions serve                        # Run all functions locally
supabase functions deploy send-push-notification # Deploy one function
supabase secrets list                           # Show all secrets
supabase secrets set KEY=value                  # Set a secret
```

### Logs

```bash
supabase logs                                   # All logs
supabase logs db                                # Database only
supabase logs --follow                          # Live tail
supabase functions logs send-push-notification  # Function logs
```

### Status

```bash
supabase status     # Show running services + keys
supabase stop       # Stop all services
supabase start      # Start all services
```

---

## Next Steps

- See [ARCHITECTURE.md](ARCHITECTURE.md) for complete technical reference
- See [README.md](README.md) for quick start guide
- See [CHANGELOG.md](CHANGELOG.md) for version history
