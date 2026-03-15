-- 🔹 32_fix_staff_access_and_realtime.sql
-- This migration fixes RLS and Realtime issues reported by staff users.

-- 1. Enable REPLICA IDENTITY FULL for orders
-- This ensures that UPDATE events sent via Supabase Realtime contain the full row data,
-- which is critical for the mobile app's stream listeners to correctly identify impacts.
ALTER TABLE public.orders REPLICA IDENTITY FULL;

-- 2. Optimize RLS Policies for Orders
-- We use the helper get_my_company_id() to avoid expensive/recursive subqueries.
DROP POLICY IF EXISTS "Staff can read orders assigned to them" ON public.orders;
DROP POLICY IF EXISTS "Staff can view open deliveries for their company" ON public.orders;

CREATE POLICY "Staff can view relevant orders" ON public.orders
    FOR SELECT
    USING (
        auth.role() = 'authenticated' AND (
            -- Assigned directly to them
            delivery_staff_id = auth.uid() OR
            -- OR open for claiming in their company
            (is_delivery_open = true AND company_id = public.get_my_company_id())
        )
    );

-- 3. Ensure Staff can view Inventory
DROP POLICY IF EXISTS "Company members can view inventory" ON public.inventory_items;
CREATE POLICY "Company members can view inventory" ON public.inventory_items
    FOR SELECT USING (
        auth.role() = 'authenticated' AND 
        company_id = public.get_my_company_id()
    );

-- 4. Enable Realtime for inventory_items (Ensuring it's in the publication)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'inventory_items'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.inventory_items;
    END IF;
END $$;
