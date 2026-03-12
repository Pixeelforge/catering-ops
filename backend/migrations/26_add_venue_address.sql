-- Migration: 26_add_venue_address
-- Description: Adds venue_address column to the orders table.

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS venue_address TEXT;
