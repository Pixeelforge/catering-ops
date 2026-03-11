-- 🔹 1. REMOVE DUPLICATE PROFILES
-- This query automatically finds users with the same phone number
-- and keeps ONLY the MOST RECENTLY CREATED profile.
-- It deletes all older duplicate profiles so the unique constraint can be applied.
DELETE FROM public.profiles 
WHERE id IN (
  SELECT id
  FROM (
      SELECT id,
      ROW_NUMBER() OVER(PARTITION BY phone ORDER BY updated_at DESC) as row_num
      FROM public.profiles
      WHERE phone IS NOT NULL
  ) t
  WHERE t.row_num > 1
);

-- 🔹 2. MAKE PHONE NUMBERS UNIQUE
-- Now that older duplicates are automatically removed, we can safely enforce the unique constraint.
ALTER TABLE public.profiles ADD CONSTRAINT unique_phone UNIQUE (phone);
