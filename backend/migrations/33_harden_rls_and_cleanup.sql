-- 🔹 33_harden_rls_and_cleanup.sql
-- This migration hardens RLS policies to prevent multi-tenancy leaks and cleans up legacy/insecure policies.

-- 1. HARDEN ORDERS TABLE
-- Drop legacy insecure policies
DROP POLICY IF EXISTS "Owners can view all orders" ON public.orders;
DROP POLICY IF EXISTS "Staff can view all orders" ON public.orders;
DROP POLICY IF EXISTS "Only owners can manage orders" ON public.orders;
DROP POLICY IF EXISTS "Owners can manage their company orders" ON public.orders;

-- New hardened policy for Owners (STRICT TENANCY)
CREATE POLICY "Owners can manage their company orders" ON public.orders
    FOR ALL
    USING (
        auth.role() = 'authenticated' AND
        company_id = (SELECT company_id FROM public.profiles WHERE id = auth.uid() AND role = 'owner')
    )
    WITH CHECK (
        auth.role() = 'authenticated' AND
        company_id = (SELECT company_id FROM public.profiles WHERE id = auth.uid() AND role = 'owner')
    );

-- 2. HARDEN NOTIFICATIONS TABLE
DROP POLICY IF EXISTS "Staff can insert notifications for company owner" ON public.notifications;

CREATE POLICY "Members can insert notifications for their company" ON public.notifications
    FOR INSERT WITH CHECK (
        auth.role() = 'authenticated' AND
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND company_id = notifications.company_id
        )
    );

-- 3. ENSURE PROFILES PRIVACY
DROP POLICY IF EXISTS "Owners can see their company staff" ON public.profiles;
CREATE POLICY "Owners can see their company staff" ON public.profiles
    FOR SELECT USING (
        auth.role() = 'authenticated' AND
        company_id = (SELECT company_id FROM public.profiles WHERE id = auth.uid() AND role = 'owner')
    );

-- 4. LOG CLEANUP
COMMENT ON TABLE public.orders IS 'Hardened RLS applied on 2026-03-15 to enforce strict multi-tenancy.';
