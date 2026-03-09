-- 🔹 AUTO CLEANUP JOIN REQUESTS ON STAFF REMOVAL
-- When an owner removes a staff member (sets their profile company_id to NULL),
-- we should automatically delete their old accepted join request so they can
-- freely request to join again in the future.

CREATE OR REPLACE FUNCTION public.handle_staff_removal()
RETURNS TRIGGER AS $$
BEGIN
    -- If company_id was just set to NULL (staff removed from company)
    IF NEW.company_id IS NULL AND OLD.company_id IS NOT NULL THEN
        DELETE FROM public.company_join_requests
        WHERE staff_id = NEW.id AND company_id = OLD.company_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_staff_removed ON public.profiles;
CREATE TRIGGER on_staff_removed
    AFTER UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_staff_removal();
