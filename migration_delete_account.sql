-- 1. Preserve Conversations
ALTER TABLE public.conversations 
DROP CONSTRAINT IF EXISTS conversations_buyer_id_fkey;

ALTER TABLE public.conversations 
ADD CONSTRAINT conversations_buyer_id_fkey 
FOREIGN KEY (buyer_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.conversations 
DROP CONSTRAINT IF EXISTS conversations_seller_id_fkey;

ALTER TABLE public.conversations 
ADD CONSTRAINT conversations_seller_id_fkey 
FOREIGN KEY (seller_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- 2. Preserve Shipping Requests
ALTER TABLE public.shipping_requests 
DROP CONSTRAINT IF EXISTS shipping_requests_user_id_fkey;

ALTER TABLE public.shipping_requests 
ADD CONSTRAINT shipping_requests_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
