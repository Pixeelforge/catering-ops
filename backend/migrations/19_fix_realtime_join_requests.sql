-- 🔹 Fix realtime for company_join_requests
-- This ensures INSERT/UPDATE/DELETE events fire for the join requests table.

-- Step 1: Enable REPLICA IDENTITY FULL so UPDATE events include the full row
-- (without this, UPDATE events miss column values through Supabase Realtime)
ALTER TABLE public.company_join_requests REPLICA IDENTITY FULL;

-- Step 2: Ensure company_join_requests is in the supabase_realtime publication
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'company_join_requests'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.company_join_requests;
  END IF;
END $$;

-- Step 3: Also ensure profiles is still in (needed for staff online status)
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

-- Step 4: Ensure orders is still in (needed for staff order updates)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
  END IF;
END $$;
