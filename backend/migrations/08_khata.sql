-- Create middle_men table for Khata/Ledger
CREATE TABLE IF NOT EXISTS public.middle_men (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    total_balance NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.middle_men ENABLE ROW LEVEL SECURITY;

-- Policies for middle_men
-- 1. Anyone in the same company can view middlemen
DROP POLICY IF EXISTS "Users can view middlemen of their company" ON public.middle_men;
CREATE POLICY "Users can view middlemen of their company"
    ON public.middle_men FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.company_id = middle_men.company_id
        )
    );

-- 2. Only Owners can insert/update/delete middlemen (standard for Khata features)
-- However, since the user asked for staff to also "send to khata", we should allow staff to UPDATE but maybe not DELETE?
-- For now, let's allow anyone in the same company to manage them to keep it simple, or stick to Owner-only if preferred.
-- User said: "if the phone is lost if he tries to login to another account then it will be a big problem"
-- This implies the data should be available for the same "Account" (which is linked to a Company).

DROP POLICY IF EXISTS "Users in company can manage middlemen" ON public.middle_men;
CREATE POLICY "Users in company can manage middlemen"
    ON public.middle_men FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.company_id = middle_men.company_id
        )
    );

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_middle_men_updated_at ON public.middle_men;
CREATE TRIGGER update_middle_men_updated_at
    BEFORE UPDATE ON public.middle_men
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Add index for performance
CREATE INDEX IF NOT EXISTS middle_men_company_id_idx ON public.middle_men(company_id);
CREATE INDEX IF NOT EXISTS middle_men_phone_number_idx ON public.middle_men(phone_number);
