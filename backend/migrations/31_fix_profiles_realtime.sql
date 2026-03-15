-- 🔹 31_fix_profiles_realtime.sql
-- This ensures that Supabase Realtime always provides the full row data on updates for the profiles table.
-- Without this, UPDATE events through Supabase Realtime might miss column values unless filtering is very specific.

-- Step 1: Enable REPLICA IDENTITY FULL so UPDATE events include the full row
ALTER TABLE public.profiles REPLICA IDENTITY FULL;

-- Step 2: Ensure profiles is in the supabase_realtime publication
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  END IF;
END $$;
