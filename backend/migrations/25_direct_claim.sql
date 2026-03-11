-- 🔹 RPC TO DIRECTLY CLAIM AN ORDER (FASTEST FINGER FIRST)
-- This ensures there is no race condition if two staff try to claim exactly at the same millisecond.

CREATE OR REPLACE FUNCTION public.claim_direct_delivery(p_order_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order_status TEXT;
    v_is_open BOOLEAN;
    v_bidding_ends_at TIMESTAMP WITH TIME ZONE;
    v_company_id UUID;
    v_staff_company_id UUID;
BEGIN
    -- 1. Get the order details WITH an exclusive row lock
    -- FOR UPDATE SKIP LOCKED guarantees that if someone else is currently locking this row 
    -- (meaning they are in the middle of claiming it), we won't wait and block, we'll just fail gracefully.
    -- However, a standard FOR UPDATE is fine since the transaction is tiny.
    SELECT order_status, is_delivery_open, delivery_bidding_ends_at, company_id 
    INTO v_order_status, v_is_open, v_bidding_ends_at, v_company_id
    FROM public.orders 
    WHERE id = p_order_id
    FOR UPDATE;

    -- 2. Validate Order Status 
    IF NOT FOUND OR v_order_status != 'upcoming' OR NOT v_is_open THEN
        RETURN FALSE; -- Order not found, not upcoming, or no longer open
    END IF;

    -- 3. Validate it is a Direct Claim (not an auction)
    IF v_bidding_ends_at IS NOT NULL THEN
        RETURN FALSE; -- This is an auction, cannot be direct claimed via this RPC
    END IF;

    -- 4. Validate the caller is staff for the exact SAME company
    SELECT company_id INTO v_staff_company_id
    FROM public.profiles
    WHERE id = auth.uid() AND role = 'staff';

    IF v_staff_company_id IS NULL OR v_staff_company_id != v_company_id THEN
        RETURN FALSE; -- Not authorized or not staff of this company
    END IF;

    -- 5. Give them the order! 
    UPDATE public.orders
    SET 
        delivery_staff_id = auth.uid(),
        is_delivery_open = false
    WHERE id = p_order_id;

    RETURN TRUE;
END;
$$;
