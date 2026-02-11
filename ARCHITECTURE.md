# Architecture Overview

Complete technical reference for the DeConnect Supabase backend.

---

## Database Schema

### Tables (12)

| Table               | Purpose                       |                       Key Columns                               |
|---------------------|-------------------------------|-----------------------------------------------------------------|
| `profiles`          | User accounts.                | id, username, full_name, avatar_url, role, is_online, is_banned |
| `chat_rooms`        | Chat containers (group + DM)  | id, name, type, created_by, max_members |
| `room_members`      | Chat membership               | room_id, user_id, role, joined_at |
| `messages`          | Chat messages                 | id, room_id, sender_id, content, media_url, is_read |
| `typing_indicators` | Real-time typing status       | user_id, room_id, is_typing, updated_at |
| `posts`             | Social feed posts             | id, user_id, content, image_url, image_path, tag |
| `comments`          | Post comments                 | id, post_id, user_id, content |
| `group_invite_links`| Group invitation system       | id, room_id, invite_code, expires_at, max_uses |
| `system_logs`       | Audit trail                   | id, action, actor_id, target_id, details |
| `calls`             | Voice/video call records      | id, room_id, initiated_by, status, started_at |
| `call_participants` | Call participation            | id, call_id, user_id, joined_at, left_at |
| `post_image_deletions` | Image cleanup queue         | id, post_id, bucket_id, object_path, processed |

### Relationships

```
profiles ──< room_members >── chat_rooms
profiles ──< messages >────── chat_rooms
profiles ──< posts
profiles ──< comments >────── posts
profiles ──< typing_indicators >── chat_rooms
chat_rooms ──< group_invite_links
chat_rooms ──< calls ──< call_participants
posts ──< post_image_deletions
```

### Storage Buckets (4)

| Bucket        |.     Purpose.                             |
|---------------|-------------------------------------------|
| `avatars`.    | User profile images |
| `post-images` | Social feed post images |
| `chat-images` | Chat image attachments |
| `chat-media`  | Chat media files (video, audio, documents) |

---

## Migration Files

Migrations run in order. Each file is self-contained and idempotent.

| File                      | Contents                                  | Lines |
|---------------------------|-------------------------------------------|------:|
| `001_extensions.sql`      | uuid-ossp, pg_trgm, pgcrypto              |.   15 |
| `002_tables.sql`          | 11 core tables with constraints and FKs.  | 319   |
| `003_indexes.sql`         | Performance indexes                       | 54    |
| `004_triggers_helpers.sql`| 41 trigger functions and helpers          | 1,207 |
| `005_rpc_functions.sql`.  | 33 callable RPC functions                 | 1,150 |
| `006_rls_policies.sql`    | 51 row-level security policies            |   427 |
| `007_storage_policies.sql`| 18 storage bucket policies                |   155 |
| `008_cleanup_post_images.sql` | post_image_deletions table + trigger  |    48 |
| `009_add_image_path.sql`.  | Add image_path column to posts           |     3 |
| **Total** |_________________________________________________________ | **3,378** |

---

## RPC Functions (33)

Called from Flutter via `Supabase.instance.client.rpc('function_name')`.

### Chat & Messaging

| Function | Purpose |
|----------|---------|
| `create_private_chat(other_user_id)` | Create or find a direct message chat |
| `create_group_chat(group_name, member_ids)` | Create a group chat with initial members |
| `create_group_with_invite(group_name, member_ids, max_members_limit, expires_in_hours)` | Create group with auto-generated invite link |
| `get_user_chat_rooms()` | List all chat rooms for the current user |
| `get_my_groups()` | List groups the current user belongs to |
| `get_my_room_ids()` | Get room IDs for realtime subscriptions |
| `get_room_members(target_room_id)` | List members of a specific room |
| `get_last_messages(room_ids)` | Get latest message per room (for chat list preview) |
| `find_direct_chat(user1_id, user2_id)` | Find existing DM between two users |
| `get_private_chat_id(user1, user2)` | Get DM room ID |
| `send_message` / `edit_message` / `delete_message` | Message CRUD |
| `mark_messages_as_read` / `mark_messages_read` | Read receipts |

### Group Management

| Function | Purpose |
|----------|---------|
| `add_member_to_room(target_room_id, new_member_id)` | Add member to group |
| `remove_member_from_group(...)` | Remove member from group |
| `leave_group(...)` | Leave a group voluntarily |
| `promote_to_admin` / `demote_from_admin` | Manage room admin roles |
| `promote_to_room_admin` / `demote_room_admin` | Alternate admin management |
| `transfer_ownership(...)` | Transfer group ownership |
| `delete_group_as_room_admin(target_room_id)` | Delete group (room admin only) |
| `update_group_settings(...)` | Update group name/description |

### Invite System

| Function | Purpose |
|----------|---------|
| `generate_invite_code()` | Generate a unique invite code |
| `regenerate_invite_code()` / `regenerate_invite_link()` | Refresh expired invites |
| `get_invite_info(invite_code_input)` | Preview invite details before joining |
| `join_group_by_code(...)` / `join_group_via_invite(...)` | Join group via invite |

### Social Feed

| Function | Purpose |
|----------|---------|
| `get_feed(page_size, page_offset, filter_tag)` | Paginated feed with optional tag filter |
| `get_post_comments(target_post_id)` | Get comments for a post |
| `get_user_post_count(target_user_id)` | Count user's posts |
| `get_user_comment_count(target_user_id)` | Count user's comments |

### User & Admin

| Function | Purpose |
|----------|---------|
| `search_users(...)` | Search users by name/username |
| `delete_my_account()` | Self-service account deletion |
| `admin_get_all_users(page_number, page_size)` | Paginated user list (admin only) |
| `admin_get_statistics()` | Dashboard stats (admin only) |
| `admin_set_user_role(target_user_id, new_role)` | Change user role (admin only) |
| `admin_set_user_ban(target_user_id, banned)` | Ban/unban user (admin only) |
| `admin_delete_group(room_id)` | Delete any group (admin only) |
| `delete_user_completely(p_user_id)` | Full user deletion (admin only) |
| `ban_user` / `unban_user` | Ban management |

### Utility

| Function | Purpose |
|----------|---------|
| `cleanup_old_logs()` | Purge old system_logs entries |
| `cleanup_stale_typing_indicators()` | Remove stale typing states |
| `is_username_available(...)` | Check username availability |

---

## Trigger & Helper Functions (41)

These run automatically on database events or support RPC functions internally.

**Realtime & Presence:** `broadcast_message_change`, `broadcast_room_change`, `heartbeat`, `update_presence`, `update_online_status`, `set_offline`, `mark_stale_users_offline`, `update_last_seen`, `set_typing_indicator`, `set_typing_status`, `update_typing_status`

**User Lifecycle:** `handle_new_user`, `handle_user_update`, `handle_user_delete`, `handle_updated_at`

**Permissions:** `is_admin`, `is_room_admin`, `set_room_creator_as_admin`

**Group Logic:** `transfer_admin_on_leave`

**Logging:** `log_comment_deletion`, `log_post_deletion_attempt`, `log_user_ban_action`, `log_error`

**Image Cleanup:** `enqueue_post_image_deletion` (trigger on post delete)

---

## Row Level Security (RLS)

All tables have RLS enabled. 51 policies control row-level access, 18 policies control storage access.

### Policy Model per Table

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| `profiles` | All users | Auth (own) | Own profile only | — |
| `chat_rooms` | Members only | Auth | Creator/admin | Creator/admin |
| `room_members` | Room members | Auth | Own membership | Own / room admin |
| `messages` | Room members | Room members | Own messages | Own messages |
| `typing_indicators` | Room members | Auth | Own indicators | Own indicators |
| `posts` | All users | Auth | Own posts | Own posts |
| `comments` | All users | Auth | Own comments | Own comments |
| `group_invite_links` | Auth | Room admin | Room admin | Room admin |
| `system_logs` | Admin only | System | — | Admin |
| `calls` | Participants | Auth | Participants | — |
| `call_participants` | Call members | Auth | Own record | Own record |

### Storage Policy Model

| Bucket | SELECT | INSERT | UPDATE | DELETE |
|--------|--------|--------|--------|--------|
| `avatars` | Public | Auth (own path) | Auth (own path) | Auth (own path) |
| `post-images` | Public | Auth | — | Auth (own) |
| `chat-images` | Auth | Auth | Auth | Auth |
| `chat-media` | Auth | Auth | Auth | Auth |

---

## Edge Functions (8)

Serverless TypeScript functions running on Deno. Called from Flutter via `Supabase.instance.client.functions.invoke('function-name')`.

| Function | Method | Purpose | Auth Required |
|----------|--------|---------|:---:|
| `send-push-notification` | POST | Deliver push notifications to users | Yes |
| `send-message` | POST | Process and validate messages before storage | Yes |
| `create-post` | POST | Create posts with image upload handling | Yes |
| `moderate-content` | POST | Filter inappropriate content in posts/comments/messages | Yes |
| `cleanup-worker` | POST | Background maintenance (stale data, old logs) | Service role |
| `group-links` | POST | Generate and validate group invite links | Yes |
| `admin-actions` | POST | Admin operations (ban, role change, group delete) | Admin only |
| `agora-token` | POST | Generate Agora RTC tokens for voice/video calls | Yes |

### Environment Variables

Required in `.env` for edge functions:

```
AGORA_APP_ID=your_app_id_here
AGORA_APP_CERTIFICATE=your_certificate_here
```

### Shared Module

`supabase/functions/_shared/cors.ts` provides standard CORS headers used across all functions.
