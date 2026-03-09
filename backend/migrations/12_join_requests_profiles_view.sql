-- Allow owners to see profiles of staff who have requested to join their company
CREATE POLICY "Owners can see joining staff profiles" ON public.profiles
    FOR SELECT
    USING (
        auth.role() = 'authenticated' AND
        id IN (
            SELECT staff_id FROM public.company_join_requests
            WHERE company_id IN (
                SELECT id FROM public.companies WHERE owner_id = auth.uid()
            )
        )
    );
