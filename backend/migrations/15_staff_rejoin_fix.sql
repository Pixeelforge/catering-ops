-- 🔹 FIX FOR STAFF RE-JOINING
-- Staff need to be able to update their existing company_join_requests row
-- if they were previously removed or rejected, so they can set it back to 'pending'.

DROP POLICY IF EXISTS "Staff can update own requests" ON public.company_join_requests;
CREATE POLICY "Staff can update own requests" ON public.company_join_requests
    FOR UPDATE USING (auth.uid() = staff_id);
    
-- Owners should also be able to delete requests, just in case they need to clean up
DROP POLICY IF EXISTS "Owners can delete requests for their company" ON public.company_join_requests;
CREATE POLICY "Owners can delete requests for their company" ON public.company_join_requests
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.companies
            WHERE id = company_join_requests.company_id
            AND owner_id = auth.uid()
        )
    );
