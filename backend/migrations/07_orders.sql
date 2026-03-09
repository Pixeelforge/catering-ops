-- Migration: 07_orders
-- Description: Creates menu_items and orders tables for the owner's Order Management tab.

-- =============================================
-- 1. menu_items table
-- =============================================
CREATE TABLE IF NOT EXISTS public.menu_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owners can manage their company menu items" ON public.menu_items;

-- EXISTS + direct column ref (no self-subquery, no recursion)
CREATE POLICY "Owners can manage their company menu items" ON public.menu_items
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
              AND p.company_id = menu_items.company_id
              AND p.role = 'owner'
        )
    );

-- =============================================
-- 2. orders table
-- =============================================
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    client_name TEXT NOT NULL,
    event_date TIMESTAMP WITH TIME ZONE NOT NULL,
    menu_items JSONB NOT NULL DEFAULT '[]'::jsonb,
    middleman_tag TEXT,
    total_value DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    payment_status TEXT NOT NULL CHECK (payment_status IN ('pending', 'paid')) DEFAULT 'pending',
    order_status TEXT NOT NULL CHECK (order_status IN ('upcoming', 'completed')) DEFAULT 'upcoming',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owners can manage their company orders" ON public.orders;

-- EXISTS + direct column ref (no self-subquery, no recursion)
CREATE POLICY "Owners can manage their company orders" ON public.orders
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
              AND p.company_id = orders.company_id
              AND p.role = 'owner'
        )
    );

-- =============================================
-- 3. Realtime subscriptions (idempotent)
-- =============================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'orders'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'menu_items'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.menu_items;
    END IF;
END $$;
