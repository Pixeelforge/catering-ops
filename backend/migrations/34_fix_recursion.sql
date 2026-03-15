-- 🔹 34_fix_recursion.sql
-- Fixes the "infinite recursion" error in profiles RLS policies by using Security Definer functions.

-- 1. Create helper functions that bypass RLS
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

-- 2. Drop the recursive policies
DROP POLICY IF EXISTS "Owners can see their company staff" ON public.profiles;
DROP POLICY IF EXISTS "Owners can manage their company orders" ON public.orders;

-- 3. Re-create Orders policy using the new function
CREATE POLICY "Owners can manage their company orders" ON public.orders
    FOR ALL
    USING (
        auth.role() = 'authenticated' AND
        company_id = get_auth_company_id() AND 
        get_auth_role() = 'owner'
    )
    WITH CHECK (
        auth.role() = 'authenticated' AND
        company_id = get_auth_company_id() AND 
        get_auth_role() = 'owner'
    );

-- 4. Re-create Profiles policy using the new functions
-- Note: Base policy allows users to see their own profile
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

-- Owners can see staff in their company
CREATE POLICY "Owners can see their company staff" ON public.profiles
    FOR SELECT USING (
        auth.role() = 'authenticated' AND
        company_id = get_auth_company_id() AND
        get_auth_role() = 'owner'
    );
