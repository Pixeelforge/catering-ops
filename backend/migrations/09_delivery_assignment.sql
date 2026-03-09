-- Migration: 09_delivery_assignment
-- Description: Adds delivery_staff_id column to orders table to allow owners to assign orders to staff.

ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS delivery_staff_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Staff can read orders assigned to them" ON public.orders;
DROP POLICY IF EXISTS "Everyone in the company can view orders" ON public.orders;

-- Current orders table has: "Owners can manage their company orders"

-- Allow staff to select orders assigned to them
CREATE POLICY "Staff can read orders assigned to them" ON public.orders
    FOR SELECT
    USING (
      delivery_staff_id = auth.uid()
    );

-- Allow staff in the same company to view orders (if needed for general visibility, but owner might want to restrict. 
-- For now, let's keep it restricted to assigned or owner based on plan).
