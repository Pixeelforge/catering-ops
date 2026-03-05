-- ⚠️ DATABASE DATA WIPE SCRIPT
-- This script removes ALL user data (Accounts, Profiles, Companies, and Orders) 
-- while keeping your tables, columns, and security policies (the "layout") intact.

-- 1. Temporarily disable foreign key triggers to allow a clean wipe
SET session_replication_role = 'replica';

-- 2. Clear all "Entered" data in the public schema
TRUNCATE TABLE public.orders RESTART IDENTITY CASCADE;
TRUNCATE TABLE public.companies RESTART IDENTITY CASCADE;
TRUNCATE TABLE public.profiles RESTART IDENTITY CASCADE;

-- 3. Clear all "Auth" data (This removes all login accounts)
DELETE FROM auth.users;

-- 4. Re-enable triggers 
SET session_replication_role = 'origin';

-- After running this, your database will be completely empty and ready for fresh testing!
