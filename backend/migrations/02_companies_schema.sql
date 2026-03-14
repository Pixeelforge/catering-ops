-- 🔹 1. CREATE COMPANIES TABLE
CREATE TABLE IF NOT EXISTS public.companies (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS for Companies
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can view a company (so staff can verify ID when joining)
DROP POLICY IF EXISTS "Anyone can view companies" ON public.companies;
CREATE POLICY "Anyone can view companies" ON public.companies
    FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Owners can update their own company" ON public.companies;
CREATE POLICY "Owners can update their own company" ON public.companies
    FOR UPDATE USING (owner_id = auth.uid());

DROP POLICY IF EXISTS "Owners can insert their own company" ON public.companies;
CREATE POLICY "Owners can insert their own company" ON public.companies
    FOR INSERT WITH CHECK (owner_id = auth.uid());

-- 🔹 2. UPDATE PROFILES TABLE
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES public.companies(id) ON DELETE SET NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;

-- Allow Owners to see profiles of their staff members
DROP POLICY IF EXISTS "Owners can view their staff" ON public.profiles;
CREATE POLICY "Owners can view their staff" ON public.profiles
    FOR SELECT USING (
        company_id IN (SELECT id FROM public.companies WHERE owner_id = auth.uid())
    );

-- 🔹 3. BACKFILL EXISTING OWNERS (If you already created accounts)
INSERT INTO public.companies (owner_id, name)
SELECT id, full_name || '''s Company' FROM public.profiles 
WHERE role = 'owner' AND NOT EXISTS (SELECT 1 FROM public.companies WHERE owner_id = public.profiles.id);

UPDATE public.profiles p
SET company_id = c.id
FROM public.companies c
WHERE p.id = c.owner_id AND p.role = 'owner';

-- 🔹 4. UPDATE TRIGGERS FOR NEW SIGNUPS
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_company_id UUID;
    user_role public.user_role;
BEGIN
    user_role := (NEW.raw_user_meta_data->>'role')::public.user_role;

    IF user_role = 'owner' THEN
        INSERT INTO public.companies (owner_id, name) 
        VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', 'Owner') || '''s Company') 
        RETURNING id INTO new_company_id;
    END IF;

    INSERT INTO public.profiles (id, full_name, phone, role, company_id)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'phone',
        user_role,
        new_company_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
