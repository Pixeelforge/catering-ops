-- Add 'is_delivery_open' to allow owners to open up deliveries for claiming
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS is_delivery_open BOOLEAN DEFAULT false;

-- Allow staff to select orders that are open for claiming for their company
CREATE POLICY "Staff can view open deliveries for their company" ON public.orders
    FOR SELECT
    USING (
        auth.role() = 'authenticated' AND 
        is_delivery_open = true AND
        company_id IN (
            SELECT company_id FROM public.profiles 
            WHERE id = auth.uid() AND role = 'staff'
        )
    );

-- Allow staff to update (claim) an open order
-- They can only claim if it's currently open and unassigned
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
    );
