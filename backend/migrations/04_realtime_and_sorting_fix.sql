-- 🔹 1. ENABLE REALTIME FOR PROFILES TABLE
-- This is critical to ensure that updates (like going offline) are broadcast to the Owner's dashboard.
begin;
  -- Use a DO block to safely handle adding the table to the publication
  do $$
  begin
    if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
      -- Remove if exists to ensure a fresh registration (Postgres doesn't support DROP TABLE IF EXISTS in ALTER PUBLICATION)
      if exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'profiles') then
        alter publication supabase_realtime drop table public.profiles;
      end if;
      alter publication supabase_realtime add table public.profiles;
    end if;
  end $$;
commit;

-- 🔹 2. ENSURE RLS FOR EVERYONE ON PROFILES (Fixing recursion)
-- Some browsers/networks struggle with complex RLS joins during Realtime.
-- Using a security definer function to avoid infinite recursion when checking company_id.

CREATE OR REPLACE FUNCTION public.get_my_company_id()
RETURNS UUID AS $$
  SELECT company_id FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

DROP POLICY IF EXISTS "View company profiles" ON public.profiles;
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
        -- staff is viewing a profile in their own company
        company_id = public.get_my_company_id()
      )
    );

-- Users can only update their own row (critical for security)
DROP POLICY IF EXISTS "Update own profile" ON public.profiles;
CREATE POLICY "Update own profile" ON public.profiles
    FOR UPDATE 
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- 🔹 3. DEFAULT VALUES
ALTER TABLE public.profiles ALTER COLUMN is_online SET DEFAULT false;
ALTER TABLE public.profiles ALTER COLUMN role SET DEFAULT 'staff'::public.user_role;
