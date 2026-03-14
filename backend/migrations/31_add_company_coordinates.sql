-- 🔹 Add latitude and longitude to Companies Table
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- 🔹 NOTE on Trigger Update
-- The handle_new_user trigger does not need to be updated because coordinates
-- will be set by the Owner later via the Dashboard UI, not during initial sign-up.
