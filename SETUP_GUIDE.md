# Setup & Development Guide

How to run DeConnect locally, make changes, and deploy to production.

---

## Prerequisites

- **Docker Desktop** — running (green whale icon visible)
- **Supabase CLI** — v2.75.0+ ([install guide](https://supabase.com/docs/guides/cli/getting-started))
- **Deno** — required for edge function development ([install](https://deno.land/manual/getting_started/installation))

---

## Local Setup

### 1. Start Supabase

```bash
cd deconnect-supabase-local
supabase start
```

Save the output. You will need `API URL` and `anon key` for Flutter.

### 2. Apply Migrations

```bash
supabase db reset
```

This drops and recreates the database, runs all 9 migration files in order, and applies seed data.

### 3. Verify in Studio

Open [http://localhost:54323](http://localhost:54323) and confirm:

- **Table Editor** → 12 tables visible
- **Database → Functions** → 74 functions listed
- **Authentication → Policies** → RLS enabled on all tables

### 4. Connect Flutter

```dart
// lib/core/config/supabase_config.dart
static const String supabaseUrl = 'http://localhost:54321';
static const String supabaseAnonKey = 'YOUR_ANON_KEY';  // from step 1
```

### 5. Run Edge Functions 

```bash
supabase functions serve
supabase functions serve create-post --no-verify-jwt
```

Functions become available at `http://localhost:54321/functions/v1/<function-name>`.

For the Agora token function, create a `.env` file from the template:

```bash
cp .env.example .env
# Edit .env with your Agora credentials
supabase functions serve --env-file .env
```

---

## Local URLs

| Service | URL |
|---------|-----|
| API | http://localhost:54321 |
| Studio | http://localhost:54323 |
| Database | postgresql://postgres:postgres@localhost:54322/postgres |

---

## Daily Workflow

### Start / Stop

```bash
supabase start       # Start all services
supabase stop        # Stop all services
supabase status      # Check if running
```

### Apply Schema Changes

```bash
# 1. Edit the relevant file in supabase/migrations/
# 2. Reset the database to apply
supabase db reset

# 3. Regenerate the overview file (keeps it in sync)
cat supabase/migrations/*.sql > migrations/schema_overview.sql

# 4. Test in Studio
open http://localhost:54323
```

### Which File to Edit

| Change | File |
|--------|------|
| Add or modify a table | `supabase/migrations/20260209000002_tables.sql` |
| Add an index | `supabase/migrations/20260209000003_indexes.sql` |
| Add or modify a trigger | `supabase/migrations/20260209000004_triggers_helpers.sql` |
| Add or modify an RPC function | `supabase/migrations/20260209000005_rpc_functions.sql` |
| Add or modify an RLS policy | `supabase/migrations/20260209000006_rls_policies.sql` |
| Change storage policies | `supabase/migrations/20260209000007_storage_policies.sql` |

For new features that require their own migration, create a new file with the next sequence number (e.g. `20260209000010_feature_name.sql`).

### Test Edge Functions

```bash
# Test a specific function
curl -X POST http://localhost:54321/functions/v1/send-push-notification \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{"userId": "test-user-id", "title": "Test", "body": "Hello"}'
```

---

## Adding a New Edge Function

```bash
# 1. Create the function
supabase functions new my-function

# 2. Edit supabase/functions/my-function/index.ts

# 3. Serve locally
supabase functions serve

# 4. Test
curl -X POST http://localhost:54321/functions/v1/my-function \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

## Git Workflow

### Before Committing

```bash
supabase db reset    # Confirm migrations apply cleanly
cat supabase/migrations/*.sql > migrations/schema_overview.sql
# Update CHANGELOG.md with your changes
git add -A
git commit -m "feat: description"
```

### Commit Message Convention

```
feat: add new feature
fix: correct bug in RLS policy
refactor: reorganize trigger functions
docs: update architecture overview
```

---

## Deployment to Production

### Link to Cloud Project

```bash
supabase link --project-ref YOUR_PROJECT_REF
```

### Push Database

```bash
supabase db push
```

### Deploy Edge Functions

```bash
for func in supabase/functions/*/; do
  fname=$(basename "$func")
  [ "$fname" = "_shared" ] && continue
  supabase functions deploy "$fname"
done
```

### Set Environment Variables

```bash
supabase secrets set AGORA_APP_ID=your_app_id
supabase secrets set AGORA_APP_CERTIFICATE=your_certificate
```

### Update Flutter Config

```dart
static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
static const String supabaseAnonKey = 'YOUR_CLOUD_ANON_KEY';
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Docker not running | Open Docker Desktop, wait for the green whale icon |
| Port already in use | `supabase stop && supabase start` |
| Migration failed | Check SQL syntax in the failing file, then `supabase db reset` |
| Flutter cannot connect | Run `supabase status`, verify the API URL and anon key match your config |
| RLS blocks a query | Expected behavior — ensure the user is authenticated and accessing their own data |
| Edge function 404 | Run `supabase functions serve` and check the function name matches the directory |
| Database out of sync | `supabase db reset` reapplies everything from scratch |

### View Logs

```bash
supabase logs          # All logs
supabase logs db       # Database only
supabase logs --follow # Real-time tail
```

### Full Reset

```bash
supabase stop
supabase start
supabase db reset
```
