-- 🔹 CUSTOM ROLES (enums)
CREATE TYPE public.user_role AS ENUM ('owner', 'staff');

-- 🔹 PROFILES TABLE
-- This table stores extra user information like Full Name and Role
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    full_name TEXT,
    phone TEXT,
    role public.user_role NOT NULL DEFAULT 'staff',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 🔹 ORDERS TABLE
-- Holds the catering orders
CREATE TABLE public.orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_by UUID REFERENCES public.profiles(id),
    client_name TEXT NOT NULL,
    client_phone TEXT,
    event_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'confirmed', 'completed', 'cancelled'
    total_amount DECIMAL(10, 2) DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 🔹 ENABLE ROW LEVEL SECURITY (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- 🔹 PROFILE POLICIES
-- Users can view their own profile
-- 1. Users can view their own profile
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

-- 2. Users can update their own profile
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- 🔹 ORDER POLICIES
-- 3. Owners can view all orders
DROP POLICY IF EXISTS "Owners can view all orders" ON public.orders;
CREATE POLICY "Owners can view all orders" ON public.orders
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'owner'
        )
    );

-- Staff can view orders assigned to them or all (depending on app logic)
-- 4. Staff can view all orders
DROP POLICY IF EXISTS "Staff can view all orders" ON public.orders;
CREATE POLICY "Staff can view all orders" ON public.orders
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'staff'
        )
    );

-- 5. Only owners can create/edit orders
DROP POLICY IF EXISTS "Only owners can manage orders" ON public.orders;
CREATE POLICY "Only owners can manage orders" ON public.orders
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'owner'
        )
    );

-- 🔹 TRIGGER: SYNC AUTH USERS TO PUBLIC.PROFILES
-- Automatically create a profile when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, phone, role)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'phone',
        (NEW.raw_user_meta_data->>'role')::public.user_role
    );
    RETURN NEW;
END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
