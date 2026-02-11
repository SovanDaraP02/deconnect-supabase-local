# DeConnect — Supabase Backend

The backend infrastructure for DeConnect, a social networking and messaging platform built on Supabase. This repository contains the complete database schema, security policies, edge functions, and local development configuration.

## Project Structure

```
deconnect-supabase-local/
├── README.md                        ← This file
├── CHANGELOG.md                     ← Version history
├── .env.example                     ← Environment variable template
│
├── docs/
│   ├── ARCHITECTURE.md              ← System overview (schema, functions, policies, edge functions)
│   └── SETUP_GUIDE.md               ← Local development & deployment guide
│
├── supabase/                        ← Runnable Supabase project
│   ├── config.toml                  ← Supabase local configuration
│   ├── seed.sql                     ← Test seed data
│   ├── migrations/                  ← Database migrations (applied in order)
│   │   ├── 001_extensions.sql       ← PostgreSQL extensions
│   │   ├── 002_tables.sql           ← 11 core tables
│   │   ├── 003_indexes.sql          ← Performance indexes
│   │   ├── 004_triggers_helpers.sql ← Trigger functions & helpers
│   │   ├── 005_rpc_functions.sql    ← RPC business logic (33 functions)
│   │   ├── 006_rls_policies.sql     ← Row Level Security (51 policies)
│   │   ├── 007_storage_policies.sql ← Storage bucket permissions (18 policies)
│   │   ├── 008_cleanup_post_images.sql ← Post image cleanup queue
│   │   └── 009_add_image_path.sql   ← Add image_path column to posts
│   └── functions/                   ← 8 Edge Functions
│       ├── _shared/                 ← Shared CORS headers
│       ├── admin-actions/           ← Admin user management
│       ├── agora-token/             ← Voice/video call tokens
│       ├── cleanup-worker/          ← Automated maintenance
│       ├── create-post/             ← Post creation with validation
│       ├── group-links/             ← Group invite link generation
│       ├── moderate-content/        ← Content moderation
│       ├── send-message/            ← Message processing
│       └── send-push-notification/  ← Push notification delivery
│
├── migrations/
│   ├── schema_overview.sql          ← Combined read-only overview (all migrations merged)
│   └── 20260208163019_remote_schema.sql ← Original remote export (reference only)
│
└── tests/
    └── flutter_connection_test.dart ← Flutter connection test
```

## Quick Start

Prerequisites: **Docker Desktop** (running) and **Supabase CLI** v2.75.0+.

```bash
# 1. Start Supabase
cd deconnect-supabase-local
supabase start          # Save the API URL + anon key from the output

# 2. Apply all migrations and seed data
supabase db reset

# 3. Open Studio to verify
open http://localhost:54323
```

Connect Flutter by updating your Supabase config to `http://localhost:54321` with the anon key from step 1. See [docs/SETUP_GUIDE.md](./docs/SETUP_GUIDE.md) for the full walkthrough.

## System Summary

| Component | Count | Details |
|-----------|------:|---------|
| Tables | 12 | Core data models + image cleanup queue |
| RLS Policies | 51 | Row-level security on all tables |
| Storage Policies | 18 | Bucket-level access control |
| Trigger / Helper Functions | 41 | Automated workflows & utilities |
| RPC Functions | 33 | Callable business logic |
| Edge Functions | 8 | Serverless TypeScript functions |
| Storage Buckets | 4 | avatars, post-images, chat-images, chat-media |

For the complete system breakdown, see [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md).

## Making Changes

```bash
# 1. Edit the appropriate migration file in supabase/migrations/
# 2. Apply and test locally
supabase db reset
# 3. Regenerate the overview file
cat supabase/migrations/*.sql > migrations/schema_overview.sql
# 4. Update CHANGELOG.md
# 5. Commit
git add -A && git commit -m "feat: description of change"
```

## Deployment

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
for func in supabase/functions/*/; do
  supabase functions deploy $(basename $func)
done
```

## Documentation

| Document | Purpose |
|----------|---------|
| [ARCHITECTURE.md](./docs/ARCHITECTURE.md) | Full system overview — tables, functions, policies, edge functions |
| [SETUP_GUIDE.md](./docs/SETUP_GUIDE.md) | Local development setup, daily workflows, deployment, troubleshooting |
| [CHANGELOG.md](./CHANGELOG.md) | Version history with all changes |