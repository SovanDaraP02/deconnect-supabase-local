-- ============================================================================
-- DATABASE INDEXES
-- ============================================================================
--
-- Performance indexes for all tables
--
-- Part of DeConnect Database Schema
-- Apply migrations in numerical order
--
-- ============================================================================

CREATE INDEX chat_rooms_created_by_idx ON public.chat_rooms USING btree (created_by);
CREATE INDEX chat_rooms_invite_code_idx ON public.chat_rooms USING btree (invite_code);
CREATE INDEX chat_rooms_is_group_idx ON public.chat_rooms USING btree (is_group);
CREATE INDEX comments_created_at_idx ON public.comments USING btree (created_at DESC);
CREATE INDEX comments_post_id_created_at_idx ON public.comments USING btree (post_id, created_at DESC);
CREATE INDEX comments_post_id_idx ON public.comments USING btree (post_id);
CREATE INDEX comments_user_id_idx ON public.comments USING btree (user_id);
CREATE INDEX group_invite_links_invite_code_idx ON public.group_invite_links USING btree (invite_code);
CREATE INDEX group_invite_links_is_active_idx ON public.group_invite_links USING btree (is_active);
CREATE INDEX group_invite_links_room_id_idx ON public.group_invite_links USING btree (room_id);
CREATE INDEX idx_calls_callee_id ON public.calls USING btree (callee_id);
CREATE INDEX idx_calls_caller_id ON public.calls USING btree (caller_id);
CREATE INDEX idx_calls_room_id ON public.calls USING btree (room_id);
CREATE INDEX idx_chat_rooms_invite_code ON public.chat_rooms USING btree (invite_code);
CREATE INDEX idx_chat_rooms_is_group ON public.chat_rooms USING btree (is_group);
CREATE INDEX idx_messages_system ON public.messages USING btree (room_id, is_system_message);
CREATE INDEX idx_profiles_is_online ON public.profiles USING btree (is_online);
CREATE INDEX idx_profiles_last_seen ON public.profiles USING btree (last_seen);
CREATE INDEX idx_room_members_role ON public.room_members USING btree (role);
CREATE UNIQUE INDEX idx_unique_group_name_per_user ON public.chat_rooms USING btree (created_by, name) WHERE ((is_group = true) AND (name IS NOT NULL));
CREATE INDEX messages_created_at_idx ON public.messages USING btree (created_at DESC);
CREATE INDEX messages_deleted_at_idx ON public.messages USING btree (deleted_at);
CREATE INDEX messages_is_read_idx ON public.messages USING btree (is_read);
CREATE INDEX messages_room_id_created_at_idx ON public.messages USING btree (room_id, created_at DESC);
CREATE INDEX messages_room_id_idx ON public.messages USING btree (room_id);
CREATE INDEX messages_sender_id_idx ON public.messages USING btree (sender_id);
CREATE INDEX messages_status_idx ON public.messages USING btree (status);
CREATE INDEX posts_created_at_idx ON public.posts USING btree (created_at DESC);
CREATE INDEX posts_created_at_user_id_idx ON public.posts USING btree (created_at DESC, user_id);
CREATE INDEX posts_tags_idx ON public.posts USING gin (tags);
CREATE INDEX posts_user_id_idx ON public.posts USING btree (user_id);
CREATE INDEX profiles_email_idx ON public.profiles USING btree (email);
CREATE INDEX profiles_is_banned_idx ON public.profiles USING btree (is_banned);
CREATE INDEX profiles_role_idx ON public.profiles USING btree (role);
CREATE INDEX profiles_username_idx ON public.profiles USING btree (username);
CREATE INDEX room_members_admin_order_idx ON public.room_members USING btree (admin_order);
CREATE INDEX room_members_is_admin_idx ON public.room_members USING btree (is_admin);
CREATE INDEX room_members_room_id_idx ON public.room_members USING btree (room_id);
CREATE INDEX room_members_user_id_idx ON public.room_members USING btree (user_id);
CREATE INDEX room_members_user_id_room_id_idx ON public.room_members USING btree (user_id, room_id);
CREATE INDEX system_logs_created_at_idx ON public.system_logs USING btree (created_at DESC);
CREATE INDEX system_logs_level_created_at_idx ON public.system_logs USING btree (level, created_at DESC);
CREATE INDEX system_logs_level_idx ON public.system_logs USING btree (level);
CREATE INDEX system_logs_user_id_idx ON public.system_logs USING btree (user_id);