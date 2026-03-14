-- 🔹 Add Address to Companies Table
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS address TEXT;

-- 🔹 REFRESH THE TRIGGER TO INCLUDE ADDRESS
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_company_id UUID;
    user_role public.user_role;
    custom_company_name TEXT;
    custom_company_address TEXT;
BEGIN
    -- Determine role (default to staff if not provided)
    user_role := COALESCE((NEW.raw_user_meta_data->>'role')::public.user_role, 'staff');
    custom_company_name := NEW.raw_user_meta_data->>'company_name';
    custom_company_address := NEW.raw_user_meta_data->>'company_address';

    -- If they are an owner, automatically create a company for them
    -- We explicitly cast to public.user_role to be 100% sure of the IF condition
    IF user_role = 'owner'::public.user_role THEN
        INSERT INTO public.companies (owner_id, name, address) 
        VALUES (
            NEW.id, 
            COALESCE(custom_company_name, COALESCE(NEW.raw_user_meta_data->>'full_name', 'Owner') || '''s Company'),
            custom_company_address
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
