-- 🔹 1. CREATE INVITATIONS TABLE
CREATE TABLE IF NOT EXISTS public.company_invitations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    phone TEXT NOT NULL,
    full_name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(company_id, phone)
);

-- 🔹 2. ENABLE RLS
ALTER TABLE public.company_invitations ENABLE ROW LEVEL SECURITY;

-- 🔹 3. RLS POLICIES
-- Owners can insert invitations for their company
CREATE POLICY "Owners can create invitations for their company" ON public.company_invitations
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.companies
            WHERE id = company_invitations.company_id
            AND owner_id = auth.uid()
        )
    );

-- Owners can view invitations for their company
CREATE POLICY "Owners can view invitations for their company" ON public.company_invitations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.companies
            WHERE id = company_invitations.company_id
            AND owner_id = auth.uid()
        )
    );

-- Anyone can view their own invitations by phone (This requires filtering logic on the client side since phone isn't part of auth by default, but we can allow everyone to query if they know the phone number, or we use a secure function later. For simplicity, allow select for anyone so the app can fetch during signup).
-- A safer approach: restrict select to authenticated users but since they sign up *first* and then check, auth.uid() is available.
CREATE POLICY "Authenticated users can select invitations" ON public.company_invitations
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete their invitations" ON public.company_invitations
    FOR DELETE USING (auth.role() = 'authenticated');
