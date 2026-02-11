-- ============================================================================
-- STORAGE POLICIES
-- ============================================================================
--
-- File upload and storage bucket security policies
-- Controls access to avatars, images, and media files
--
-- Part of DeConnect Database Schema
-- Apply in order: 07_storage_policies.sql
--
-- ============================================================================

  create policy "Anyone can view avatars"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'avatars'::text));


  create policy "Anyone can view post images"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'post-images'::text));


  create policy "Authenticated users can upload post images"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'post-images'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Authenticated users can view chat images"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'chat-images'::text));


  create policy "Members can upload chat media"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'chat-media'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Members can view chat media"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'chat-media'::text));


  create policy "Room members can upload chat images"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'chat-images'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can delete own chat images"
  on "storage"."objects"
  as permissive
  for delete
  to public
using (((bucket_id = 'chat-images'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can delete own chat media"
  on "storage"."objects"
  as permissive
  for delete
  to public
using (((bucket_id = 'chat-media'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can delete their own avatar"
  on "storage"."objects"
  as permissive
  for delete
  to public
using (((bucket_id = 'avatars'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can delete their own post images"
  on "storage"."objects"
  as permissive
  for delete
  to public
using (((bucket_id = 'post-images'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can update own chat media"
  on "storage"."objects"
  as permissive
  for update
  to public
using (((bucket_id = 'chat-media'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can update their own avatar"
  on "storage"."objects"
  as permissive
  for update
  to public
using (((bucket_id = 'avatars'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can update their own post images"
  on "storage"."objects"
  as permissive
  for update
  to public
using (((bucket_id = 'post-images'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can upload their own avatar"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'avatars'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "chat_images_delete"
  on "storage"."objects"
  as permissive
  for delete
  to authenticated
using (((bucket_id = 'chat-images'::text) AND ((auth.uid())::text = (string_to_array(name, '/'::text))[2])));


  create policy "chat_images_upload"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check ((bucket_id = 'chat-images'::text));


  create policy "chat_images_view"
  on "storage"."objects"
  as permissive
  for select
  to authenticated
using ((bucket_id = 'chat-images'::text));

