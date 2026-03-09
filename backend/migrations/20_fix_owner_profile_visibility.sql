-- 🔹 Fix joining staff profile visibility for owners
-- If an owner doesn't have permission to see a staff's profile, the 
-- join query in JoinRequestsScreen will fail to return complete data.

-- Step 1: Ensure REPLICA IDENTITY FULL for profiles
-- (Needed for real-time join data consistency)
ALTER TABLE public.profiles REPLICA IDENTITY FULL;

-- Step 2: Policy to allow owners to see joining staff profiles
-- Drops existing if any to ensure fresh policy
DROP POLICY IF EXISTS "Owners can see joining staff profiles" ON public.profiles;

CREATE POLICY "Owners can see joining staff profiles" ON public.profiles
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.company_join_requests
            WHERE company_id IN (
                SELECT id FROM public.companies WHERE owner_id = auth.uid()
            )
            AND staff_id = profiles.id
            -- We only allow seeing them if they have a pending or active request
            AND status IN ('pending', 'accepted')
        )
    );

-- Step 3: Ensure company_join_requests has REPLICA IDENTITY FULL as well
ALTER TABLE public.company_join_requests REPLICA IDENTITY FULL;
