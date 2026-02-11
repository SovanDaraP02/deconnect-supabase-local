# Changelog

All notable changes to the DeConnect Supabase backend.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [0.4.0] — 2026-02-11

### Changed
- Restructured documentation for production use: README, ARCHITECTURE.md, SETUP_GUIDE.md, CHANGELOG
- Removed redundant documentation files (COMMANDS.md, 8 overlapping docs in docs/)
- Fixed all documentation references to match actual code paths and file structure
- Corrected system statistics across all documentation

### Removed
- `COMMANDS.md` — merged into SETUP_GUIDE.md
- `docs/DATABASE_SCHEMA.md` — merged into ARCHITECTURE.md
- `docs/RPC_FUNCTIONS.md` — merged into ARCHITECTURE.md
- `docs/RLS_POLICIES.md` — merged into ARCHITECTURE.md
- `docs/EDGE_FUNCTIONS.md` — merged into ARCHITECTURE.md
- `docs/MIGRATION_GUIDE.md` — merged into SETUP_GUIDE.md
- `docs/RUNNING_LOCALLY_GUIDE.md` — merged into SETUP_GUIDE.md
- `docs/QUICK_CHEAT_SHEET.md` — merged into SETUP_GUIDE.md
- `docs/GITHUB_GUIDE.md` — generic content, not project-specific
- `fix_duplicates.sh`, `deduplicate_policies.py`, `reorganize_project.sh` — one-time utility scripts
- `supabase/snippets/` — local Studio query drafts

---

## [0.3.1] — 2026-02-10

### Added
- Migration 008: `post_image_deletions` table and `enqueue_post_image_deletion` trigger for cleanup queue when posts with images are deleted
- Migration 009: `image_path` column on `posts` table to store original storage path
- `create-post` edge function for post creation with image upload handling

### Current Stats
- Tables: 12
- RLS Policies: 51 | Storage Policies: 18
- Trigger/Helper Functions: 41 | RPC Functions: 33
- Edge Functions: 8
- Migration Lines: 3,378

---

## [0.3.0] — 2026-02-10

### Fixed
- Added RLS enable and 4 policies for `call_participants` table
- Synced `schema_overview.sql` to match running migrations

### Added
- `supabase/config.toml` for local development
- Supabase seed data (`supabase/seed.sql`)

---

## [0.2.0] — 2026-02-09

### Added
- Split monolithic migration into 7 separate files (001–007)
- 8 edge functions: admin-actions, agora-token, cleanup-worker, create-post, group-links, moderate-content, send-message, send-push-notification
- Shared CORS module (`supabase/functions/_shared/cors.ts`)
- Row Level Security on all tables
- Documentation suite

### Architecture
- Separate migration files in `supabase/migrations/` for running and editing
- Combined `migrations/schema_overview.sql` for code review and onboarding

---

## [0.1.0] — 2026-02-08

### Added
- Initial schema export from remote Supabase project

---

## Migration File Reference

| File | Contents | Lines |
|------ |----------|------:|
| 001_extensions | uuid-ossp, pg_trgm, pgcrypto | 15 |
| 002_tables | 11 core tables with constraints | 319 |
| 003_indexes | Performance indexes | 54 |
| 004_triggers_helpers | 41 trigger functions and helpers | 1,207 |
| 005_rpc_functions | 33 callable RPC functions | 1,150 |
| 006_rls_policies | 51 row-level security policies | 427 |
| 007_storage_policies | 18 storage bucket policies | 155 |
| 008_cleanup_post_images | Image cleanup queue table + trigger | 48 |
| 009_add_image_path | image_path column on posts | 3 |
| **Total** | | **3,378** |