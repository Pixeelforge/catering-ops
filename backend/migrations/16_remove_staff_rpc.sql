-- 🔹 1. CREATE SECURE RPC TO REMOVE STAFF
-- Bypasses complex RLS select/update conflicts by using SECURITY DEFINER.
-- It explicitly checks if the caller is the owner of the company the staff currently belongs to.

CREATE OR REPLACE FUNCTION public.remove_staff_member(staff_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    target_company_id UUID;
    is_authorized BOOLEAN;
BEGIN
    -- Get the company_id of the staff member
    SELECT company_id INTO target_company_id 
    FROM public.profiles 
    WHERE id = staff_user_id;

    -- If they don't have a company, do nothing
    IF target_company_id IS NULL THEN
        RETURN;
    END IF;

    -- Check if the person calling this function is the owner of that company
    SELECT EXISTS (
        SELECT 1 FROM public.companies 
        WHERE id = target_company_id AND owner_id = auth.uid()
    ) INTO is_authorized;

    IF NOT is_authorized THEN
        RAISE EXCEPTION 'Not authorized to remove this staff member';
    END IF;

    -- Perform the removals
    -- 1. Remove their join request so they can re-join later
    DELETE FROM public.company_join_requests 
    WHERE staff_id = staff_user_id AND company_id = target_company_id;

    -- 2. Nullify their company_id
    UPDATE public.profiles 
    SET company_id = NULL 
    WHERE id = staff_user_id;
END;
$$;
