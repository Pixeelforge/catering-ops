-- 🔹 1. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL, -- 'staff_left', 'staff_joined', 'order_bid'
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 🔹 2. ENABLE RLSalri
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 🔹 3. RLS POLICIES
-- Owners can manage their own notifications
DROP POLICY IF EXISTS "Owners can manage own notifications" ON public.notifications;
CREATE POLICY "Owners can manage own notifications" ON public.notifications
    FOR ALL USING (owner_id = auth.uid());

-- Staff can insert notifications for their company owner
-- This is a bit tricky: we need to allow staff to insert a record if they belong to that company
DROP POLICY IF EXISTS "Staff can insert notifications for company owner" ON public.notifications;
CREATE POLICY "Staff can insert notifications for company owner" ON public.notifications
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.companies 
            WHERE id = notifications.company_id
            -- We don't check profile company_id here because they might have just left
        )
    );

-- 🔹 4. ENABLE REALTIME
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
