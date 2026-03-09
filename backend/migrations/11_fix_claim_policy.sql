-- Drop the old policy that was missing the WITH CHECK clause
DROP POLICY IF EXISTS "Staff can claim open deliveries" ON public.orders;

-- Create the updated policy
-- USING: What the row must look like BEFORE the update (must be open and unassigned)
-- WITH CHECK: What the row must look like AFTER the update (must be closed and assigned to themselves)
CREATE POLICY "Staff can claim open deliveries" ON public.orders
    FOR UPDATE
    USING (
        auth.role() = 'authenticated' AND 
        is_delivery_open = true AND
        delivery_staff_id IS NULL AND
        company_id IN (
            SELECT company_id FROM public.profiles 
            WHERE id = auth.uid() AND role = 'staff'
        )
    )
    WITH CHECK (
        auth.role() = 'authenticated' AND 
        is_delivery_open = false AND
        delivery_staff_id = auth.uid() AND
        company_id IN (
            SELECT company_id FROM public.profiles 
            WHERE id = auth.uid() AND role = 'staff'
        )
    );
