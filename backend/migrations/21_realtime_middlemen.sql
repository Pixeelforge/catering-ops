-- 🔹 1. ENABLE REALTIME FOR MIDDLE_MEN TABLE
-- This ensures that when a middle man is added/updated, all clients 
-- (owner/staff) see the change instantly.

DO $$
BEGIN
    -- Add to supabase_realtime publication
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'middle_men'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.middle_men;
    END IF;
END $$;

-- 🔹 2. SET REPLICA IDENTITY FULL
-- Crucial for DELETE/UPDATE events to contain all columns (needed for filtering)
ALTER TABLE public.middle_men REPLICA IDENTITY FULL;
