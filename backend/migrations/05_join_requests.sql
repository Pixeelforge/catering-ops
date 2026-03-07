-- 🔹 1. NEW TABLE FOR JOIN REQUESTS
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;

CREATE TABLE IF NOT EXISTS public.company_join_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    staff_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'accepted', 'rejected'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(staff_id, company_id) -- Prevent duplicate requests
);

-- 🔹 2. ENABLE RLS
ALTER TABLE public.company_join_requests ENABLE ROW LEVEL SECURITY;

-- 🔹 3. RLS POLICIES
-- Staff can view their own requests
CREATE POLICY "Staff can view own requests" ON public.company_join_requests
    FOR SELECT USING (auth.uid() = staff_id);

-- Staff can create requests
CREATE POLICY "Staff can create requests" ON public.company_join_requests
    FOR INSERT WITH CHECK (auth.uid() = staff_id);

-- Owners can view requests for their company
CREATE POLICY "Owners can view requests for their company" ON public.company_join_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.companies
            WHERE id = company_join_requests.company_id
            AND owner_id = auth.uid()
        )
    );

-- Owners can update (accept/reject) requests for their company
CREATE POLICY "Owners can update requests for their company" ON public.company_join_requests
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.companies
            WHERE id = company_join_requests.company_id
            AND owner_id = auth.uid()
        )
    );

-- 🔹 4. UPDATE handle_new_user TRIGGER for Company Name & Email
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_company_id UUID;
    user_role public.user_role;
    custom_company_name TEXT;
BEGIN
    user_role := COALESCE((NEW.raw_user_meta_data->>'role')::public.user_role, 'staff');
    custom_company_name := NEW.raw_user_meta_data->>'company_name';

    -- If they are an owner, automatically create a company for them
    IF user_role = 'owner' THEN
        INSERT INTO public.companies (owner_id, name) 
        VALUES (
            NEW.id, 
            COALESCE(custom_company_name, COALESCE(NEW.raw_user_meta_data->>'full_name', 'Owner') || '''s Company')
        ) 
        RETURNING id INTO new_company_id;
    END IF;

    INSERT INTO public.profiles (id, full_name, phone, role, company_id, is_online, email)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'phone',
        user_role,
        new_company_id,
        true,
        NEW.email
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 🔹 5. TRIGGER TO AUTOMATICALLY UPDATE PROFILE ON ACCEPTANCE
CREATE OR REPLACE FUNCTION public.handle_join_request_acceptance()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
        -- Link the staff to the company
        UPDATE public.profiles
        SET company_id = NEW.company_id
        WHERE id = NEW.staff_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_join_request_accepted
    AFTER UPDATE ON public.company_join_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_join_request_acceptance();

-- 🔹 6. ENABLE REALTIME FOR UPDATES
-- Add tables to the supabase_realtime publication
BEGIN;
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime FOR TABLE 
    public.company_join_requests, 
    public.profiles,
    public.companies,
    public.orders;
COMMIT;

