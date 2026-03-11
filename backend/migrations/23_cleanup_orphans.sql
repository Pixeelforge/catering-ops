-- 🔹 CLEAN UP ORPHANED PROFILES
-- Sometimes if a user is deleted from the Authentication dashboard, 
-- their public profile might accidentally remain if the database cascade fails.
-- This script safely deletes any profiles that no longer have a matching Auth account.

DELETE FROM public.profiles 
WHERE id NOT IN (SELECT id FROM auth.users);

-- We also make sure the same cleanup happens for any join requests
DELETE FROM public.company_join_requests 
WHERE staff_id NOT IN (SELECT id FROM auth.users);

-- And for company owners, if the owner was deleted
DELETE FROM public.companies 
WHERE owner_id NOT IN (SELECT id FROM auth.users);
