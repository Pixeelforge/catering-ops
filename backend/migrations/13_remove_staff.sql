-- Adding RLS Policy to allow owners to remove staff from their company
-- An owner can UPDATE a profile if:
-- 1. The profile is currently in the owner's company
-- 2. The update sets the profile's company_id to NULL
CREATE POLICY "Owners can remove staff from their company" ON public.profiles
    FOR UPDATE
    USING (
        -- The profile being updated must currently belong to a company the user owns
        company_id IN (
            SELECT id FROM public.companies WHERE owner_id = auth.uid()
        )
    )
    WITH CHECK (
        -- The owner MUST set the company_id to NULL to remove them
        company_id IS NULL AND
        
        -- And the owner MUST NOT be trying to change the user's role
        -- (Postgres doesn't make it easy to prevent updating specific columns in RLS, 
        -- but we can ensure the role stays exactly what it was before by verifying
        -- the old profile role if needed, or simply requiring standard staff management)
        role = 'staff'
    );
