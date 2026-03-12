-- Migration: 29_order_partial_payments
-- Description: Adds paid_amount column to orders table to track partial payments.

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS paid_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS is_khata_saved BOOLEAN NOT NULL DEFAULT FALSE;

-- Update existing paid orders to have paid_amount = total_value
UPDATE public.orders 
SET paid_amount = total_value 
WHERE payment_status = 'paid' AND (paid_amount IS NULL OR paid_amount = 0);
