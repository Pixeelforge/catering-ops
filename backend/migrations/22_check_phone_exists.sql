-- 🔹 RPC FUNCTION TO CHECK PHONE NUMBER EXISTENCE
-- This allows the frontend to check if a phone number is already registered
-- before attempting to sign up, preventing ugly database constraint errors.
CREATE OR REPLACE FUNCTION check_phone_exists(p_phone text)
RETURNS boolean AS $$
DECLARE
    phone_exists boolean;
BEGIN
    SELECT EXISTS(SELECT 1 FROM public.profiles WHERE phone = p_phone) INTO phone_exists;
    RETURN phone_exists;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
