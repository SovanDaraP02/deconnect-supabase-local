# Architecture Overview

Complete technical reference for the DeConnect Supabase backend.

---

## Database Schema

### Tables (16)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `profiles` | User accounts | id, username, avatar_url, role, is_online, is_banned, fcm_token |
| `chat_rooms` | Chat containers (group + DM) | id, name, is_group, created_by, max_members, invite_code, invite_expires_at |
| `room_members` | Chat membership | room_id, user_id, is_admin, role, joined_at |
| `messages` | Chat messages | id, room_id, sender_id, content, media_url, is_read, status |
| `typing_indicators` | Real-time typing status | user_id, room_id, is_typing, started_at |
| `posts` | Social feed posts | id, user_id, content, title, image_url, image_path, tags |
| `comments` | Post comments (with replies) | id, post_id, user_id, content, parent_id, mentions |
| `post_likes` | Post like tracking | id, post_id, user_id (unique per post+user) |
| `notifications` | Push notification records | id, user_id, title, body, channel, room_id, post_id, is_read |
| `user_devices` | Multi-device push support | id, user_id, device_id, fcm_token, current_room_id, push_enabled |
| `group_invite_links` | Group invitation system | id, room_id, invite_code, expires_at, max_uses, uses_count |
| `system_logs` | Enhanced audit trail | id, level, message, user_id, feature, action, metadata, source |
| `action_analytics` | Feature/action usage counters | id, date, feature, action, user_id, count, last_used_at |
| `calls` | Voice/video call records | id, room_id, caller_id, callee_id, status, call_type |
| `call_participants` | Call participation | id, call_id, user_id, status, joined_at, left_at |
| `post_image_deletions` | Image cleanup queue | id, post_id, bucket_id, object_path, processed |

### Relationships

```
profiles --< room_members >-- chat_rooms
profiles --< messages >------ chat_rooms
profiles --< posts --< comments (with parent_id self-reference for replies)
profiles --< post_likes >---- posts
profiles --< notifications
profiles --< user_devices >-- chat_rooms (current_room_id)
profiles --< typing_indicators >-- chat_rooms
profiles --< action_analytics
chat_rooms --< group_invite_links
chat_rooms --< calls --< call_participants
posts --< post_image_deletions
```

### Notification Channels (9)

| Channel | Trigger | Android Channel ID |
|---------|---------|-------------------|
| `direct_message` | New DM received | `dm_channel` |
| `group_message` | New group chat message | `group_channel` |
| `post` | New post by another user | `post_channel` |
| `comment` | Comment on your post / reply | `comment_channel` |
| `like` | Someone liked your post | `general_channel` |
| `follow` | Someone followed you | `general_channel` |
| `mention` | Mentioned in a comment | `general_channel` |
| `feed` | Feed-related notification | `general_channel` |
| `general` | System notifications | `general_channel` |

### User Devices & Push Flow

```
Flutter App                    Supabase                           FCM
    |                              |                                |
    +- register_device() --------->| upsert user_devices            |
    |  (device_id, fcm_token)      |                                |
    |                              |                                |
    +- set_current_room() -------->| update current_room_id         |
    |  (when entering chat)        |                                |
    |                              |                                |
    |  [new notification inserted] |                                |
    |                              +- trigger_send_push_notification|
    |                              |   calls edge function -------->|
    |                              |   via pg_net HTTP POST         |
    |                              |                                |
    |                              |  edge function queries         |
    |                              |  user_devices table:           |
    |                              |  - push_enabled = true         |
    |                              |  - fcm_token IS NOT NULL       |
    |                              |  - current_room_id != room_id  |
    |                              |    (skip if user viewing chat) |
    |                              |                                |
    |<---------------------------- FCM push to each device --------|
```

### Storage Buckets (4)

| Bucket | Purpose | Public | Size Limit |
|--------|---------|--------|------------|
| `avatars` | User profile images | Yes | 50 MiB |
| `post-images` | Social feed post images | Yes | 50 MiB |
| `chat-images` | Chat image attachments | Auth | 50 MiB |
| `chat-media` | Chat media (video, audio, docs) | Yes | 50 MiB |

`chat-media` supports: JPEG, PNG, GIF, WebP, BMP, MP4, QuickTime, WebM, audio (MP4/MPEG/WAV/OGG/AAC), PDF, octet-stream, plain text, CSV.

---

## Migration Files (19)

| # | File | Contents |
|---|------|----------|
| 001 | `20260209000001_extensions.sql` | pg_cron extension |
| 002 | `20260209000002_tables.sql` | 11 core tables with constraints and FKs |
| 003 | `20260209000003_indexes.sql` | Performance indexes |
| 004 | `20260209000004_triggers_helpers.sql` | 40 trigger functions and helpers |
| 005 | `20260209000005_rpc_functions.sql` | 33 callable RPC functions |
| 006 | `20260209000006_rls_policies.sql` | 51 row-level security policies |
| 007 | `20260209000007_storage_policies.sql` | 18 storage bucket policies |
| 008 | `20260209000008_cleanup_post_images.sql` | post_image_deletions table + trigger |
| 009 | `20260209000009_add_image_path_to_posts.sql` | image_path column on posts |
| 010 | `20260213000010_push_notifications.sql` | notifications table, fcm_token on profiles |
| 011 | `20260213000011_push_notification_rpcs.sql` | Message notification triggers and RPCs |
| 012 | `20260213000013_logsystem.sql` | Enhanced logging (42 functions, 29 triggers, analytics RPCs) |
| 013 | `20260217000001_post_comment_notifications.sql` | Post/comment/like notification triggers |
| 014 | `20260217000002_consolidated_notification_fixes.sql` | Clean notification triggers + push via pg_net |
| 015 | `20260218000001_user_devices.sql` | user_devices table, register_device, set_current_room RPCs, comments.mentions |
| 016 | `20260218000002_fix_type_field_triggers.sql` | Fix NEW.type trigger errors on messages/posts |
| 017 | `20260218100000_fixes.sql` | chat-media bucket fix, verbose log level, performance indexes |
| 018 | `20260218200000_comprehensive_fixes.sql` | Invite code 48h expiry, success log level, action_analytics, track_action() |

---

## RPC Functions (50+)

Called from Flutter via `Supabase.instance.client.rpc('function_name')`.

### Chat & Messaging

| Function | Purpose |
|----------|---------|
| `create_private_chat(other_user_id)` | Create or find a DM chat |
| `create_group_chat(group_name, member_ids)` | Create a group chat |
| `create_group_with_invite(...)` | Create group with auto invite link |
| `get_user_chat_rooms()` | List all chat rooms |
| `get_my_groups()` | List user's groups |
| `get_my_room_ids()` | Get room IDs for realtime |
| `get_room_members(target_room_id)` | List room members |
| `get_last_messages(room_ids)` | Latest message per room |
| `find_direct_chat(user1_id, user2_id)` | Find existing DM |
| `send_message` / `edit_message` / `delete_message` | Message CRUD |
| `mark_messages_as_read` / `mark_messages_read` | Read receipts |

### Group Management

| Function | Purpose |
|----------|---------|
| `add_member_to_room` / `remove_member_from_group` | Member management |
| `leave_group` | Leave voluntarily |
| `promote_to_admin` / `demote_from_admin` | Admin roles |
| `transfer_ownership` | Transfer group ownership |
| `delete_group_as_room_admin` | Delete group |
| `update_group_settings` | Update name/description |

### Invite System

| Function | Purpose |
|----------|---------|
| `generate_invite_code()` | Generate unique code |
| `regenerate_invite_code(p_room_id, p_expires_hours)` | Refresh with 48h default expiry |
| `regenerate_invite_link(target_room_id, expires_in_hours)` | Refresh link with 48h default |
| `get_invite_info(invite_code_input)` | Preview (includes is_expired, expires_at) |
| `join_group_by_code` / `join_group_via_invite` | Join group |

### Social Feed

| Function | Purpose |
|----------|---------|
| `get_feed(page_size, page_offset, filter_tag)` | Paginated feed |
| `get_post_comments(target_post_id)` | Post comments |
| `get_user_post_count` / `get_user_comment_count` | User stats |

### Notifications

| Function | Purpose |
|----------|---------|
| `update_fcm_token(p_token)` | Update FCM token |
| `remove_fcm_token()` | Clear token on logout |
| `notify_user(...)` | Send notification to user |
| `notify_room_members(...)` | Notify all room members |
| `get_my_notifications(p_limit, p_offset)` | Get with sender info |
| `mark_notifications_read(p_notification_ids)` | Mark as read |
| `get_unread_notification_count()` | Unread count |

### Device Management

| Function | Purpose |
|----------|---------|
| `register_device(p_device_id, p_fcm_token, p_platform, p_app_version)` | Upsert device on startup |
| `set_current_room(p_device_id, p_room_id)` | Track viewed room (null to clear) |

### Logging & Analytics

| Function | Purpose |
|----------|---------|
| `log_event(...)` | Simple log |
| `log_detailed(...)` | Detailed log + auto-track analytics |
| `log_error(...)` | Error with stack trace |
| `query_logs(...)` | Query logs (admin) |
| `get_error_summary(p_days)` | Error summary (admin) |
| `get_feature_usage(p_days, p_source)` | Feature ranking (admin) |
| `get_feature_usage_stats(p_days)` | From action_analytics (admin) |
| `get_action_usage(...)` | Action breakdown (admin) |
| `get_top_users(p_days, p_limit)` | Top users (admin) |
| `get_usage_heatmap(p_days)` | Hourly heatmap (admin) |
| `get_log_dashboard(p_days)` | Full dashboard (admin) |
| `track_action(p_feature, p_action, p_user_id)` | Increment counter |

### User & Admin

| Function | Purpose |
|----------|---------|
| `search_users(...)` | Search by name/username |
| `delete_my_account()` | Self-service deletion |
| `admin_get_all_users(...)` | Paginated users (admin) |
| `admin_get_statistics()` | Dashboard stats (admin) |
| `admin_set_user_role` / `admin_set_user_ban` | Role/ban management |
| `admin_delete_group` / `delete_user_completely` | Admin deletion |
| `ban_user` / `unban_user` | Ban management |

### Utility

| Function | Purpose |
|----------|---------|
| `cleanup_old_logs()` | Purge old logs |
| `cleanup_stale_typing_indicators()` | Remove stale typing |
| `is_username_available(...)` | Check availability |

---

## Trigger & Helper Functions (85+)

**Realtime & Presence:** broadcast_message_change, broadcast_room_change, heartbeat, update_presence, update_online_status, set_offline, mark_stale_users_offline, update_last_seen, set_typing_indicator, set_typing_status, update_typing_status

**User Lifecycle:** handle_new_user, handle_user_update, handle_user_delete, handle_updated_at

**Permissions:** is_admin, is_room_admin, set_room_creator_as_admin

**Group Logic:** transfer_admin_on_leave

**Notifications:** trigger_send_push_notification (DB to edge function via pg_net), notify_on_new_comment (post owner + reply), notify_on_new_post (all non-banned), notify_on_new_message (room members), notify_on_post_like (with 1h dedup)

**Logging (29 triggers):** messages sent/edited/deleted, typing, member join/leave, user register/login/offline, feed refresh, post like/unlike, comment created/deleted, notifications created/read/deleted, calls started/status, call participants joined/update, posts created, group created/updated/deleted, admin role change, user role change, user deleted, profile updated, invite used

**Image Cleanup:** enqueue_post_image_deletion

**Device Management:** update_user_devices_updated_at

**Analytics:** track_action (auto from log_detailed)

---

## RLS Policy Summary

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| `profiles` | All users | Auth (own) | Own only | Own only |
| `chat_rooms` | Members only | Auth | Creator/admin | Creator/admin |
| `room_members` | Room members | Auth | Own membership | Own / admin |
| `messages` | Room members | Room members | Own messages | Own messages |
| `typing_indicators` | Room members | Auth | Own | Own |
| `posts` | All users | Auth | Own posts | Own posts |
| `comments` | All users | Auth | Own comments | Own comments |
| `post_likes` | All users | Auth | --- | Own likes |
| `notifications` | Own only | Auth | Own only | Own only |
| `user_devices` | Own only | Auth (own) | Own only | Own only |
| `group_invite_links` | Auth | Room admin | Room admin | Room admin |
| `system_logs` | Own / Admin | Auth | --- | --- |
| `action_analytics` | Own / Admin | Auth | --- | --- |
| `calls` | Participants | Auth | Participants | --- |
| `call_participants` | Call members | Auth | Own record | Own record |

### Storage Policies

| Bucket | SELECT | INSERT | UPDATE | DELETE |
|--------|--------|--------|--------|--------|
| `avatars` | Public | Auth (own path) | Auth (own path) | Auth (own path) |
| `post-images` | Public | Auth | --- | Auth (own) |
| `chat-images` | Auth | Auth | Auth | Auth |
| `chat-media` | Public | Auth | Auth | Auth |

---

## Edge Functions (8)

| Function | Method | Purpose | Auth |
|----------|--------|---------|------|
| `send-push-notification` | POST | FCM push to all user devices | Service role |
| `send-message` | POST | Validate messages before storage | User |
| `create-post` | POST | Posts with image upload | User |
| `moderate-content` | POST | Content filtering | User |
| `cleanup-worker` | POST | Background maintenance | Service role |
| `group-links` | POST | Invite link management | User |
| `admin-actions` | POST | Ban, role change, delete | Admin |


### Shared Modules

| Module | Exports | Purpose |
|--------|---------|---------|
| `cors.ts` | `corsHeaders` | CORS headers |
| `supabase.ts` | `getServiceClient()`, `getAuthClient(req)`, `getBearerToken(req)` | Client factory |
| `helpers.ts` | `json(status, data)`, `handleCors(req)` | Response helpers |

### Environment Variables

```
FCM_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
AGORA_APP_ID=your_app_id_here
AGORA_APP_CERTIFICATE=your_certificate_here
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` are auto-set by Supabase.

### Security

- Firebase credentials from `FCM_SERVICE_ACCOUNT_JSON` env var (never committed)
- `service-account.json` blocked by `.gitignore`
- Push trigger reads key from `current_setting('app.settings.service_role_key')` with local fallback
- Invite codes expire after 48 hours by default
