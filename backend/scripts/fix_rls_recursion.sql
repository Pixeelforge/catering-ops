-- 🚨 CONSOLIDATED RLS RECURSION FIX 🚨
-- Run this in your Supabase SQL Editor to fix the 500 Infinite Recursion error.

-- 1. Create Helper Functions (SECURITY DEFINER bypasses RLS to break the loop)
CREATE OR REPLACE FUNCTION public.get_auth_company_id()
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT company_id FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.get_auth_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- 2. Clean up problematic policies
DROP POLICY IF EXISTS "Owners can see their company staff" ON public.profiles;
DROP POLICY IF EXISTS "Owners can manage their company orders" ON public.orders;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;

-- 3. Re-implement Profiles policies safely
-- Base policy: You can always see your own profile
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

-- Team policy: Owners can see staff in their company (using the helper function)
CREATE POLICY "Owners can see their company staff" ON public.profiles
    FOR SELECT USING (
        auth.role() = 'authenticated' AND
        get_auth_role() = 'owner' AND
        company_id = get_auth_company_id()
    );

-- 4. Re-implement Orders policy safely
CREATE POLICY "Owners can manage their company orders" ON public.orders
    FOR ALL
    USING (
        auth.role() = 'authenticated' AND
        get_auth_role() = 'owner' AND
        company_id = get_auth_company_id()
    )
    WITH CHECK (
        auth.role() = 'authenticated' AND
        get_auth_role() = 'owner' AND
        company_id = get_auth_company_id()
    );

-- 5. Harden Notifications policy (prevent recursion here too)
DROP POLICY IF EXISTS "Members can insert notifications for their company" ON public.notifications;
CREATE POLICY "Members can insert notifications for their company" ON public.notifications
    FOR INSERT WITH CHECK (
        auth.role() = 'authenticated' AND
        company_id = get_auth_company_id()
    );
