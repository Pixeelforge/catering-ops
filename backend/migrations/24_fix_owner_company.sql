-- 🔹 FIX ORPHANED OWNERS
-- Sometimes, if users are deleted but companies are left in a tangled state, 
-- new signups might miss getting their company_id assigned correctly.
-- This script safely re-creates missing companies for owners and links them.

DO $$
DECLARE
    r RECORD;
    new_company_id UUID;
BEGIN
    FOR r IN SELECT id, full_name, role, company_id FROM public.profiles WHERE role = 'owner' AND company_id IS NULL LOOP
        -- Create a company for the owner
        INSERT INTO public.companies (owner_id, name)
        VALUES (r.id, COALESCE(r.full_name, 'Owner') || '''s Company')
        RETURNING id INTO new_company_id;

        -- Update the profile with the new company
        UPDATE public.profiles SET company_id = new_company_id WHERE id = r.id;
    END LOOP;
END;
$$;

-- 🔹 REFRESH THE TRIGGER
-- We also make sure the trigger evaluates the role properly 
-- using an explicit enum cast to prevent silent failures.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_company_id UUID;
    user_role public.user_role;
    custom_company_name TEXT;
BEGIN
    -- Determine role (default to staff if not provided)
    user_role := COALESCE((NEW.raw_user_meta_data->>'role')::public.user_role, 'staff');
    custom_company_name := NEW.raw_user_meta_data->>'company_name';

    -- If they are an owner, automatically create a company for them
    -- We explicitly cast to public.user_role to be 100% sure of the IF condition
    IF user_role = 'owner'::public.user_role THEN
        INSERT INTO public.companies (owner_id, name) 
        VALUES (
            NEW.id, 
            COALESCE(custom_company_name, COALESCE(NEW.raw_user_meta_data->>'full_name', 'Owner') || '''s Company')
        ) 
        RETURNING id INTO new_company_id;
    END IF;

    -- Create their profile
    INSERT INTO public.profiles (id, full_name, phone, role, company_id, is_online, email)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'phone',
        user_role,
        new_company_id,
        true,
        NEW.email
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
