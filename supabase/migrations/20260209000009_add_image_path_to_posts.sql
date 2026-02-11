-- Add `image_path` column to public.posts to store original storage path
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS image_path text;
