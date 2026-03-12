-- 🔹 ADD LOCATION FIELDS TO PROFILES
-- To enable owners to share staff location, we need to store it
ALTER TABLE public.profiles 
ADD COLUMN last_latitude DOUBLE PRECISION,
ADD COLUMN last_longitude DOUBLE PRECISION,
ADD COLUMN location_updated_at TIMESTAMP WITH TIME ZONE;
