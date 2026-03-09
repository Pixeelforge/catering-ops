-- ⚠️ DATABASE DATA WIPE SCRIPT (Robust Version)
-- This script removes ALL user data while preserving your table structure.
-- It handles missing tables gracefully!

-- 1. Temporarily disable foreign key triggers to allow a clean wipe
SET session_replication_role = 'replica';

-- 2. Clear data using a safe block (won't crash if a table is missing)
DO $$ 
BEGIN
    -- Clear Orders
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'orders') THEN
        EXECUTE 'TRUNCATE TABLE public.orders RESTART IDENTITY CASCADE';
    END IF;

    -- Clear Companies
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'companies') THEN
        EXECUTE 'TRUNCATE TABLE public.companies RESTART IDENTITY CASCADE';
    END IF;

    -- Clear Profiles
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'profiles') THEN
        EXECUTE 'TRUNCATE TABLE public.profiles RESTART IDENTITY CASCADE';
    END IF;
END $$;

-- 3. Clear all "Auth" data (This removes all login accounts/emails)
-- Note: This requires high permissions, which you normally have in Suapbase SQL Editor.
DELETE FROM auth.users;

-- 4. Re-enable triggers 
SET session_replication_role = 'origin';

-- After running this, your database will be completely empty and ready for fresh testing!
