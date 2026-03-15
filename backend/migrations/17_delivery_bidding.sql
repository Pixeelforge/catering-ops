-- 🔹 1. NEW COLUMNS ON ORDERS
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_fare NUMERIC;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_bidding_ends_at TIMESTAMP WITH TIME ZONE;

-- 🔹 2. NEW TABLE FOR DELIVERY BIDS
CREATE TABLE IF NOT EXISTS public.delivery_bids (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    bid_amount NUMERIC NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(order_id, staff_id) -- Staff can only have one active bid per order
);

-- 🔹 3. RLS POLICIES FOR BIDS
ALTER TABLE public.delivery_bids ENABLE ROW LEVEL SECURITY;

-- Staff can insert their own bids
DROP POLICY IF EXISTS "Staff can place bids" ON public.delivery_bids;
CREATE POLICY "Staff can place bids" ON public.delivery_bids
    FOR INSERT WITH CHECK (auth.uid() = staff_id);

-- Staff can view their own bids
DROP POLICY IF EXISTS "Staff can view own bids" ON public.delivery_bids;
CREATE POLICY "Staff can view own bids" ON public.delivery_bids
    FOR SELECT USING (auth.uid() = staff_id);

-- Owners can view all bids for orders in their company
DROP POLICY IF EXISTS "Owners can view all bids for their orders" ON public.delivery_bids;
CREATE POLICY "Owners can view all bids for their orders" ON public.delivery_bids
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.orders o
            JOIN public.companies c ON o.company_id = c.id
            WHERE o.id = delivery_bids.order_id
            AND c.owner_id = auth.uid()
        )
    );

-- Finds the lowest bid and assigns the order when the timer expires
CREATE OR REPLACE FUNCTION public.resolve_delivery_auction(p_order_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_bidding_ends_at TIMESTAMP WITH TIME ZONE;
    v_is_open BOOLEAN;
    v_winning_staff_id UUID;
    v_winning_bid NUMERIC;
BEGIN
    -- 1. Get the auction status
    SELECT delivery_bidding_ends_at, is_delivery_open 
    INTO v_bidding_ends_at, v_is_open
    FROM public.orders 
    WHERE id = p_order_id;

    -- 2. Validate it's actually eligible
    IF NOT v_is_open THEN
        RETURN json_build_object('was_resolved', false, 'winning_staff_id', NULL); 
    END IF;

    IF v_bidding_ends_at IS NULL OR v_bidding_ends_at > NOW() THEN
        RETURN json_build_object('was_resolved', false, 'winning_staff_id', NULL);
    END IF;

    -- 3. Find the lowest bid
    SELECT staff_id, bid_amount 
    INTO v_winning_staff_id, v_winning_bid
    FROM public.delivery_bids
    WHERE order_id = p_order_id
    ORDER BY bid_amount ASC, created_at ASC
    LIMIT 1;

    -- 4. If someone bid, assign them.
    IF v_winning_staff_id IS NOT NULL THEN
        UPDATE public.orders
        SET 
            delivery_staff_id = v_winning_staff_id,
            delivery_fare = v_winning_bid,
            is_delivery_open = false,
            delivery_bidding_ends_at = NULL -- Clear the timer
        WHERE id = p_order_id;
        
        RETURN json_build_object('was_resolved', true, 'winning_staff_id', v_winning_staff_id);
    ELSE
        -- No bids, maybe clear the timer but keep it open?
        -- Actually, if timer expired and no bids, we should probably close the bidding status
        -- but leave it as a "Fastest claim (Direct)" or let owner re-assign.
        UPDATE public.orders
        SET 
            delivery_bidding_ends_at = NULL,
            is_delivery_open = true -- Keep it open for direct claim
        WHERE id = p_order_id;
        
        RETURN json_build_object('was_resolved', false, 'winning_staff_id', NULL);
    END IF;
END;
$$;
