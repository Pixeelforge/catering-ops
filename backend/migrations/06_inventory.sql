-- 🔹 1. CREATE INVENTORY TABLE
CREATE TABLE IF NOT EXISTS public.inventory_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    quantity DECIMAL NOT NULL DEFAULT 0,
    unit TEXT NOT NULL DEFAULT 'units',
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 🔹 2. ENABLE RLS
ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;

-- 🔹 3. RLS POLICIES

-- Anyone in the company can view the inventory
CREATE POLICY "Company members can view inventory" ON public.inventory_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.company_id = inventory_items.company_id
        )
    );

-- Only owners can insert into their company's inventory
CREATE POLICY "Owners can create inventory items" ON public.inventory_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'owner'
            AND profiles.company_id = inventory_items.company_id
        )
    );

-- Only owners can update their company's inventory
CREATE POLICY "Owners can update inventory items" ON public.inventory_items
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'owner'
            AND profiles.company_id = inventory_items.company_id
        )
    );

-- Only owners can delete their company's inventory
CREATE POLICY "Owners can delete inventory items" ON public.inventory_items
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'owner'
            AND profiles.company_id = inventory_items.company_id
        )
    );

-- 🔹 4. ENABLE REALTIME
BEGIN;
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.company_join_requests, 
    public.profiles,
    public.companies,
    public.orders,
    public.inventory_items;
COMMIT;
