-- 🔹 ENSURE ALL PERMISSIONS ARE CORRECT
-- This script fixes any RLS issues that might prevent staff from joining or viewing their dashboard.

-- 1. Ensure Profiles table has all columns
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS company_id UUID;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;

-- 2. Ensure Companies table exists and has RLS
CREATE TABLE IF NOT EXISTS public.companies (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;

-- 3. DROP AND RECREATE POLICIES (to ensure they are fresh)
DROP POLICY IF EXISTS "Anyone can view companies" ON public.companies;
DROP POLICY IF EXISTS "Owners can update their own company" ON public.companies;
DROP POLICY IF EXISTS "Owners can insert their own company" ON public.companies;

CREATE POLICY "Anyone can view companies" ON public.companies
    FOR SELECT USING (true); -- Allow all authenticated users (and even anon) to check if a company code is valid

CREATE POLICY "Owners can manage their own company" ON public.companies
    FOR ALL USING (owner_id = auth.uid());

-- 4. PROFILE POLICIES (Fixing update issues)
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Owners can view their staff" ON public.profiles;

-- Users can always see and update their OWN profile (Critical for Staff joining)
CREATE POLICY "Users can manage own profile" ON public.profiles
    FOR ALL USING (auth.uid() = id);

-- Owners can see profiles of people in their company
CREATE POLICY "Owners can see their company staff" ON public.profiles
    FOR SELECT USING (
        company_id IN (
            SELECT id FROM public.companies WHERE owner_id = auth.uid()
        )
    );

-- 5. RE-SYNC TRIGGERS
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_company_id UUID;
    user_role public.user_role;
BEGIN
    user_role := COALESCE((NEW.raw_user_meta_data->>'role')::public.user_role, 'staff');

    -- If they are an owner, automatically create a company for them
    IF user_role = 'owner' THEN
        INSERT INTO public.companies (owner_id, name) 
        VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', 'Owner') || '''s Company') 
        RETURNING id INTO new_company_id;
    END IF;

    INSERT INTO public.profiles (id, full_name, phone, role, company_id, is_online)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'phone',
        user_role,
        new_company_id,
        true
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
