-- 🔹 1. ENABLE REALTIME FOR PROFILES TABLE
-- This is critical to ensure that updates (like going offline) are broadcast to the Owner's dashboard.
begin;
  -- Remove the table from publication first to avoid errors
  alter publication supabase_realtime drop table if exists public.profiles;
  -- Add it back (this ensures it's properly registered)
  alter publication supabase_realtime add table public.profiles;
commit;

-- 🔹 2. ENSURE RLS FOR EVERYONE ON PROFILES (Safest for Team Visibility)
-- Some browsers/networks struggle with complex RLS joins during Realtime.
-- Let's simplify the SELECT policy while keeping UPDATE secure.

DROP POLICY IF EXISTS "Owners can see their company staff" ON public.profiles;
DROP POLICY IF EXISTS "Users can manage own profile" ON public.profiles;

-- Anyone logged in can see profiles in their company
CREATE POLICY "View company profiles" ON public.profiles
    FOR SELECT 
    USING (
      auth.role() = 'authenticated' AND (
        -- User is viewing their own profile
        auth.uid() = id OR
        -- owner is viewing a profile with their company_id
        company_id IN (SELECT id FROM public.companies WHERE owner_id = auth.uid()) OR
        -- staff is viewing a profile with their company_id (optional, but good for team view)
        company_id IN (SELECT company_id FROM public.profiles WHERE id = auth.uid())
      )
    );

-- Users can only update their own row (critical for security)
CREATE POLICY "Update own profile" ON public.profiles
    FOR UPDATE 
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- 🔹 3. DEFAULT VALUES
ALTER TABLE public.profiles ALTER COLUMN is_online SET DEFAULT false;
ALTER TABLE public.profiles ALTER COLUMN role SET DEFAULT 'staff'::public.user_role;
