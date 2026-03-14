-- 🔹 1. CREATE MENU CATEGORIES TABLE
CREATE TABLE IF NOT EXISTS public.menu_categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 🔹 2. CREATE MENU ITEMS TABLE
CREATE TABLE IF NOT EXISTS public.menu_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.menu_categories(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    base_price DECIMAL(10, 2) NOT NULL DEFAULT 0,
    is_veg BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 🔹 3. ENABLE RLS
ALTER TABLE public.menu_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;

-- 🔹 4. RLS POLICIES FOR CATEGORIES

-- Anyone in the company can view menu categories
CREATE POLICY "Company members can view menu categories" ON public.menu_categories
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.company_id = menu_categories.company_id
        )
    );

-- Only owners can insert categories
CREATE POLICY "Owners can create menu categories" ON public.menu_categories
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'owner'
            AND profiles.company_id = menu_categories.company_id
        )
    );

-- Only owners can update their company's categories
CREATE POLICY "Owners can update menu categories" ON public.menu_categories
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'owner'
            AND profiles.company_id = menu_categories.company_id
        )
    );

-- Only owners can delete their company's categories
CREATE POLICY "Owners can delete menu categories" ON public.menu_categories
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'owner'
            AND profiles.company_id = menu_categories.company_id
        )
    );

-- 🔹 5. RLS POLICIES FOR ITEMS

-- Anyone in the company can view menu items
CREATE POLICY "Company members can view menu items" ON public.menu_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.company_id = menu_items.company_id
        )
    );

-- Only owners can insert items
CREATE POLICY "Owners can create menu items" ON public.menu_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'owner'
            AND profiles.company_id = menu_items.company_id
        )
    );

-- Only owners can update their company's items
CREATE POLICY "Owners can update menu items" ON public.menu_items
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'owner'
            AND profiles.company_id = menu_items.company_id
        )
    );

-- Only owners can delete their company's items
CREATE POLICY "Owners can delete menu items" ON public.menu_items
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'owner'
            AND profiles.company_id = menu_items.company_id
        )
    );

-- 🔹 6. ADD TO REALTIME PUBLICATION
-- We need to manually alter the publication to add the new tables.
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM pg_publication 
        WHERE pubname = 'supabase_realtime'
    ) THEN
        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.menu_categories;
        EXCEPTION WHEN duplicate_object THEN
            -- Table already in publication
        END;
        
        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.menu_items;
        EXCEPTION WHEN duplicate_object THEN
            -- Table already in publication
        END;
    END IF;
END $$;
