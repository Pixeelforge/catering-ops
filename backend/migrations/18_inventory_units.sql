-- 1. Inventory Items Table
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

-- 2. Inventory Units Table
CREATE TABLE IF NOT EXISTS public.inventory_units (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(company_id, name)
);

-- 3. Enable Security
ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_units ENABLE ROW LEVEL SECURITY;

-- 4. Policies (Items)
DROP POLICY IF EXISTS "Company members can view inventory" ON public.inventory_items;
CREATE POLICY "Company members can view inventory" ON public.inventory_items
    FOR SELECT USING (EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.company_id = inventory_items.company_id));

DROP POLICY IF EXISTS "Owners can manage inventory" ON public.inventory_items;
CREATE POLICY "Owners can manage inventory" ON public.inventory_items
    FOR ALL USING (EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'owner' AND profiles.company_id = inventory_items.company_id));

-- 5. Policies (Units)
DROP POLICY IF EXISTS "Company members can view units" ON public.inventory_units;
CREATE POLICY "Company members can view units" ON public.inventory_units
    FOR SELECT USING (EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.company_id = inventory_units.company_id));

DROP POLICY IF EXISTS "Owners can manage units" ON public.inventory_units;
CREATE POLICY "Owners can manage units" ON public.inventory_units
    FOR ALL USING (EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'owner' AND profiles.company_id = inventory_units.company_id));

-- 6. Enable Realtime (Defensive)
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'inventory_items') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.inventory_items;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'inventory_units') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.inventory_units;
    END IF;
  END IF;
END $$;
