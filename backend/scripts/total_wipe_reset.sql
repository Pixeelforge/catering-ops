-- 🗑️ 1. WIPE ALL APPLICATION DATA
TRUNCATE TABLE 
    public.company_join_requests,
    public.orders,
    public.companies,
    public.profiles
RESTART IDENTITY CASCADE;

-- 🗑️ 2. WIPE ALL AUTH USERS (CRITICAL)
-- This removes users from the Supabase Auth system entirely
DELETE FROM auth.users;

-- 🔄 3. OPTIONAL: VERIFY TRIGGER IS ACTIVE
-- The handle_new_user trigger should now correctly use the company_name from metadata
