-- ============================================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================================
--
-- Security policies for all database tables
-- These policies control who can access which rows
--
-- Part of DeConnect Database Schema
-- Apply in order: 06_rls_policies.sql
--
-- ============================================================================

-- CALLS POLICIES
create policy "Users can create calls"
  on "public"."calls"
  as permissive
  for insert
  to public
with check ((auth.uid() = caller_id));

create policy "Users can see their own calls"
  on "public"."calls"
  as permissive
  for select
  to public
using (((auth.uid() = caller_id) OR (auth.uid() = callee_id)));

create policy "Users can update their calls"
  on "public"."calls"
  as permissive
  for update
  to public
using (((auth.uid() = caller_id) OR (auth.uid() = callee_id)));

-- CHAT ROOMS POLICIES
create policy "chat_rooms_insert"
  on "public"."chat_rooms"
  as permissive
  for insert
  to authenticated
with check ((created_by = auth.uid()));

create policy "chat_rooms_select"
  on "public"."chat_rooms"
  as permissive
  for select
  to authenticated
using (((id IN ( SELECT public.get_my_room_ids() AS get_my_room_ids)) OR (created_by = auth.uid())));

create policy "chat_rooms_update"
  on "public"."chat_rooms"
  as permissive
  for update
  to authenticated
using (((created_by = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.room_members
  WHERE ((room_members.room_id = chat_rooms.id) AND (room_members.user_id = auth.uid()) AND ((room_members.role)::text = 'admin'::text))))));

-- COMMENTS POLICIES
create policy "comments_delete"
  on "public"."comments"
  as permissive
  for delete
  to authenticated
using (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text))))));

create policy "comments_insert_own"
  on "public"."comments"
  as permissive
  for insert
  to authenticated
with check ((user_id = auth.uid()));

create policy "comments_select_all"
  on "public"."comments"
  as permissive
  for select
  to authenticated
using (true);

create policy "comments_update"
  on "public"."comments"
  as permissive
  for update
  to authenticated
using ((user_id = auth.uid()))
with check ((user_id = auth.uid()));

-- GROUP INVITE LINKS POLICIES
create policy "Active invite links are viewable by everyone"
  on "public"."group_invite_links"
  as permissive
  for select
  to public
using ((is_active = true));

create policy "Room admins can manage invite links"
  on "public"."group_invite_links"
  as permissive
  for all
  to public
using ((EXISTS ( SELECT 1
   FROM public.room_members rm
  WHERE ((rm.room_id = group_invite_links.room_id) AND (rm.user_id = auth.uid()) AND (rm.is_admin = true)))))
with check ((EXISTS ( SELECT 1
   FROM public.room_members rm
  WHERE ((rm.room_id = group_invite_links.room_id) AND (rm.user_id = auth.uid()) AND (rm.is_admin = true)))));

-- MESSAGES POLICIES
create policy "Room members can update messages"
  on "public"."messages"
  as permissive
  for update
  to public
using ((room_id IN ( SELECT room_members.room_id
   FROM public.room_members
  WHERE (room_members.user_id = auth.uid()))))
with check ((room_id IN ( SELECT room_members.room_id
   FROM public.room_members
  WHERE (room_members.user_id = auth.uid()))));

create policy "Users can delete their own messages"
  on "public"."messages"
  as permissive
  for delete
  to public
using (((sender_id = auth.uid()) OR (auth.uid() IN ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.role = 'admin'::text)))));

create policy "Users can insert messages in their rooms"
  on "public"."messages"
  as permissive
  for insert
  to public
with check (((sender_id = auth.uid()) AND (room_id IN ( SELECT room_members.room_id
   FROM public.room_members
  WHERE (room_members.user_id = auth.uid())))));

create policy "Users can read messages in their rooms"
  on "public"."messages"
  as permissive
  for select
  to public
using ((EXISTS ( SELECT 1
   FROM public.room_members rm
  WHERE ((rm.room_id = messages.room_id) AND (rm.user_id = auth.uid())))));

create policy "Users can send messages to their rooms"
  on "public"."messages"
  as permissive
  for insert
  to public
with check (((auth.uid() = sender_id) AND (EXISTS ( SELECT 1
   FROM public.room_members rm
  WHERE ((rm.room_id = messages.room_id) AND (rm.user_id = auth.uid()))))));

create policy "Users can update their own messages"
  on "public"."messages"
  as permissive
  for update
  to public
using ((sender_id = auth.uid()))
with check ((sender_id = auth.uid()));

create policy "Validate sender exists"
  on "public"."messages"
  as permissive
  for insert
  to public
with check (((auth.uid() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE (profiles.id = auth.uid())))));

create policy "messages_insert"
  on "public"."messages"
  as permissive
  for insert
  to authenticated
with check (((sender_id = auth.uid()) AND (room_id IN ( SELECT public.get_my_room_ids() AS get_my_room_ids))));

create policy "messages_insert_validated"
  on "public"."messages"
  as permissive
  for insert
  to authenticated
with check (((auth.uid() IS NOT NULL) AND (auth.uid() = sender_id) AND (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (NOT profiles.is_banned)))) AND (EXISTS ( SELECT 1
   FROM public.chat_rooms
  WHERE (chat_rooms.id = messages.room_id))) AND (EXISTS ( SELECT 1
   FROM public.room_members
  WHERE ((room_members.room_id = messages.room_id) AND (room_members.user_id = auth.uid()))))));

create policy "messages_select"
  on "public"."messages"
  as permissive
  for select
  to authenticated
using ((room_id IN ( SELECT public.get_my_room_ids() AS get_my_room_ids)));

create policy "messages_select_member"
  on "public"."messages"
  as permissive
  for select
  to authenticated
using (((auth.uid() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM public.room_members
  WHERE ((room_members.room_id = messages.room_id) AND (room_members.user_id = auth.uid()))))));

create policy "messages_update"
  on "public"."messages"
  as permissive
  for update
  to authenticated
using ((sender_id = auth.uid()))
with check ((sender_id = auth.uid()));

-- POSTS POLICIES
create policy "Authenticated users can create posts"
  on "public"."posts"
  as permissive
  for insert
  to public
with check ((auth.role() = 'authenticated'::text));

create policy "Posts are viewable by everyone"
  on "public"."posts"
  as permissive
  for select
  to public
using (true);

create policy "Users can delete own posts"
  on "public"."posts"
  as permissive
  for delete
  to authenticated
using ((user_id = auth.uid()));

create policy "Users can update own posts"
  on "public"."posts"
  as permissive
  for update
  to authenticated
using ((user_id = auth.uid()))
with check ((user_id = auth.uid()));

create policy "posts_select"
  on "public"."posts"
  as permissive
  for select
  to authenticated
using (true);

create policy "posts_update_own"
  on "public"."posts"
  as permissive
  for update
  to authenticated
using (((auth.uid() IS NOT NULL) AND (auth.uid() = user_id)))
with check ((auth.uid() = user_id));

-- PROFILES POLICIES
create policy "Admins can update any profile"
  on "public"."profiles"
  as permissive
  for update
  to authenticated
using ((EXISTS ( SELECT 1
   FROM public.profiles profiles_1
  WHERE ((profiles_1.id = auth.uid()) AND (profiles_1.role = 'admin'::text)))));

create policy "Enable insert for auth trigger"
  on "public"."profiles"
  as permissive
  for insert
  to public
with check (true);

create policy "Profiles are viewable by everyone"
  on "public"."profiles"
  as permissive
  for select
  to public
using (true);

create policy "Users can insert own profile"
  on "public"."profiles"
  as permissive
  for insert
  to public
with check ((auth.uid() = id));

create policy "Users can update own profile"
  on "public"."profiles"
  as permissive
  for update
  to public
using ((auth.uid() = id))
with check ((auth.uid() = id));

create policy "profiles_delete_own"
  on "public"."profiles"
  as permissive
  for delete
  to authenticated
using (((auth.uid() IS NOT NULL) AND (auth.uid() = id)));

create policy "profiles_insert_own"
  on "public"."profiles"
  as permissive
  for insert
  to authenticated
with check (((auth.uid() IS NOT NULL) AND (auth.uid() = id)));

create policy "profiles_select"
  on "public"."profiles"
  as permissive
  for select
  to authenticated
using (true);

-- ROOM MEMBERS POLICIES
create policy "room_members_delete"
  on "public"."room_members"
  as permissive
  for delete
  to public
using (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.chat_rooms
  WHERE ((chat_rooms.id = room_members.room_id) AND (chat_rooms.created_by = auth.uid()))))));

create policy "room_members_insert"
  on "public"."room_members"
  as permissive
  for insert
  to authenticated
with check (((EXISTS ( SELECT 1
   FROM public.chat_rooms cr
  WHERE ((cr.id = room_members.room_id) AND (cr.created_by = auth.uid())))) OR (user_id = auth.uid())));

create policy "room_members_select"
  on "public"."room_members"
  as permissive
  for select
  to authenticated
using ((room_id IN ( SELECT public.get_my_room_ids() AS get_my_room_ids)));

create policy "room_members_update"
  on "public"."room_members"
  as permissive
  for update
  to public
using ((EXISTS ( SELECT 1
   FROM public.chat_rooms
  WHERE ((chat_rooms.id = room_members.room_id) AND (chat_rooms.created_by = auth.uid())))));

-- SYSTEM LOGS POLICIES
create policy "Authenticated users can insert logs"
  on "public"."system_logs"
  as permissive
  for insert
  to public
with check (((auth.uid() IS NOT NULL) AND (auth.role() = 'authenticated'::text)));

-- TYPING INDICATORS POLICIES
create policy "Users can delete their own typing"
  on "public"."typing_indicators"
  as permissive
  for delete
  to public
using ((user_id = auth.uid()));

create policy "Users can insert their own typing"
  on "public"."typing_indicators"
  as permissive
  for insert
  to public
with check ((user_id = auth.uid()));

create policy "Users can see typing in their rooms"
  on "public"."typing_indicators"
  as permissive
  for select
  to public
using ((room_id IN ( SELECT room_members.room_id
   FROM public.room_members
  WHERE (room_members.user_id = auth.uid()))));

create policy "Users can update their own typing"
  on "public"."typing_indicators"
  as permissive
  for update
  to public
using ((user_id = auth.uid()));

-- CALL PARTICIPANTS POLICIES
create policy "Users can see their own call participation"
  on "public"."call_participants"
  as permissive
  for select
  to authenticated
using ((user_id = auth.uid()));

create policy "Users can join calls"
  on "public"."call_participants"
  as permissive
  for insert
  to authenticated
with check ((user_id = auth.uid()));

create policy "Users can update their own call status"
  on "public"."call_participants"
  as permissive
  for update
  to authenticated
using ((user_id = auth.uid()));

create policy "Users can leave calls"
  on "public"."call_participants"
  as permissive
  for delete
  to authenticated
using ((user_id = auth.uid()));
