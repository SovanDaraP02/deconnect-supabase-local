-- Migration: enqueue post image deletions and helper table
-- Adds `post_image_deletions` table and trigger to enqueue image paths when posts are deleted

CREATE TABLE IF NOT EXISTS public.post_image_deletions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL,
  bucket_id text NOT NULL,
  object_path text NOT NULL,
  created_at timestamptz DEFAULT now(),
  processed boolean DEFAULT false,
  processed_at timestamptz,
  CONSTRAINT post_image_deletions_pkey PRIMARY KEY (id)
);

CREATE OR REPLACE FUNCTION public.enqueue_post_image_deletion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  IF OLD.image_url IS NULL OR trim(OLD.image_url) = '' THEN
    RETURN OLD;
  END IF;

  -- Attempt to extract object path after '/post-images/'
  -- Works for URLs like: https://.../storage/v1/object/public/post-images/<path>
  PERFORM 1;
  INSERT INTO public.post_image_deletions (post_id, bucket_id, object_path)
  VALUES (
    OLD.id,
    'post-images',
    coalesce(substring(OLD.image_url from '/post-images/(.*)$'), '')
  );

  RETURN OLD;
END;
$function$;

-- Create trigger to enqueue when a post with image is deleted
DROP TRIGGER IF EXISTS enqueue_post_image_deletion_trigger ON public.posts;
CREATE TRIGGER enqueue_post_image_deletion_trigger
BEFORE DELETE ON public.posts
FOR EACH ROW
WHEN (OLD.image_url IS NOT NULL)
EXECUTE FUNCTION public.enqueue_post_image_deletion();

-- Index to quickly find unprocessed deletions
CREATE INDEX IF NOT EXISTS post_image_deletions_unprocessed_idx ON public.post_image_deletions (processed, created_at);
