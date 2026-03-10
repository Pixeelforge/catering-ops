-- 🔹 1. CREATE STAFF INVITATIONS TABLE
-- Allows owners to pre-link staff via email
CREATE TABLE IF NOT EXISTS public.staff_invitations (
    email TEXT PRIMARY KEY,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.staff_invitations ENABLE ROW LEVEL SECURITY;

-- Owners can manage invitations for their company
CREATE POLICY "Owners can manage invitations" ON public.staff_invitations
    FOR ALL USING (
        company_id IN (SELECT id FROM public.companies WHERE owner_id = auth.uid())
    );

-- 🔹 2. UPDATE HANDLE_NEW_USER TRIGGER
-- Automatically links staff to company if invited
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_company_id UUID;
    user_role public.user_role;
    invitation_company_id UUID;
BEGIN
    -- Determine role from metadata or default to staff
    user_role := COALESCE((NEW.raw_user_meta_data->>'role')::public.user_role, 'staff');

    -- Check if there's a pending invitation for this email
    SELECT company_id INTO invitation_company_id 
    FROM public.staff_invitations 
    WHERE public.staff_invitations.email = NEW.email;

    -- If invited, they MUST be staff and belong to that company
    IF invitation_company_id IS NOT NULL THEN
        new_company_id := invitation_company_id;
        user_role := 'staff';
    ELSIF user_role = 'owner' THEN
        -- Owners get a new company created automatically
        INSERT INTO public.companies (owner_id, name) 
        VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', 'Owner') || '''s Company') 
        RETURNING id INTO new_company_id;
    END IF;

    -- Create common profile
    INSERT INTO public.profiles (id, full_name, phone, role, company_id, is_online)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'phone',
        user_role,
        new_company_id,
        true
    );

    -- Clean up invitation if used
    IF invitation_company_id IS NOT NULL THEN
        DELETE FROM public.staff_invitations WHERE public.staff_invitations.email = NEW.email;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
