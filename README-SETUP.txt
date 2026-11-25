PRINTDESK — NETLIFY + SUPABASE SETUP
====================================

WHAT IS INCLUDED
- index.html: customer upload, ₹10/page pricing, delivery/pickup, cash/online choice, order tracking, admin UI.
- supabase-schema.sql: orders table, RLS, private file bucket, customer token lookup, price validation.
- admin-setup.sql: grants admin role to the email you choose.
- netlify/functions/: Razorpay order creation/payment verification and WhatsApp notification functions.
- netlify.toml: Netlify function configuration.

STEP 1 — SUPABASE
1. Create a Supabase project at https://supabase.com.
2. Open SQL Editor and run the complete supabase-schema.sql file.
3. In Project Settings > API, copy the Project URL and anon/public key.
4. In index.html, replace YOUR_SUPABASE_PROJECT_URL and YOUR_SUPABASE_ANON_PUBLIC_KEY.
   The anon/public key is intended for browser use. NEVER put the service_role key in index.html.
5. In Authentication > Users, create an admin user with your email and a strong password.
6. Open SQL Editor, replace YOUR_ADMIN_EMAIL@example.com in admin-setup.sql, and run it.
7. Sign out/in after assigning the admin role.

STEP 2 — NETLIFY
1. Deploy the contents of this folder to your Netlify site (index.html must be at the publish root).
2. Add these environment variables in Netlify Site configuration > Environment variables:
   SUPABASE_URL = your Supabase Project URL
   SUPABASE_SERVICE_ROLE_KEY = Supabase service_role key (server functions ONLY)
   RAZORPAY_KEY_ID = Razorpay API key ID
   RAZORPAY_KEY_SECRET = Razorpay API secret
   WHATSAPP_TOKEN = Meta WhatsApp Cloud API permanent/system-user token
   WHATSAPP_PHONE_NUMBER_ID = Meta WhatsApp sender phone-number ID
   SHOP_WHATSAPP_NUMBER = receiving shop phone number in international format, digits only (e.g. 91XXXXXXXXXX)
3. Redeploy after setting environment variables.

STEP 3 — RAZORPAY
1. Create/activate a Razorpay account and complete its required KYC.
2. Generate API keys in Razorpay Dashboard and set RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET in Netlify.
3. Test in Razorpay test mode first. Switch to live keys only after successful testing.

STEP 4 — WHATSAPP
1. Configure WhatsApp Cloud API in Meta for Developers.
2. Set the three WhatsApp variables above in Netlify.
3. For business-initiated notifications, Meta may require an approved message template and applicable opt-in. This starter sends a simple text message; adapt it to an approved template if Meta requires one for your recipient/session.

IMPORTANT SECURITY / OPERATIONS
- Never share service_role keys, Razorpay secrets, WhatsApp tokens, passwords or OTPs in chat or in the public website source.
- Keep Supabase storage bucket private. The SQL creates it as private.
- Orders are public-insert only; admin read/update is restricted to users with app_metadata role=admin.
- Customer tracking uses a long random access token stored on the same browser/device. Clearing browser storage loses the shortcut; customers should save their order number and contact the shop if needed.
- Current online checkout requires Razorpay credentials and a public HTTPS Netlify deployment. Payment verification is performed server-side before the order is marked paid.
- Before going live, test a cash pickup order, cash delivery order, online test payment, file downloads, admin status changes, and WhatsApp notification.
- PDF page count is read in the browser. If a PDF cannot be parsed, this version currently falls back to one page; confirm the count with the customer/shop before printing.
- Delivery charges are not included; all totals are ₹10 × page count × copies.
