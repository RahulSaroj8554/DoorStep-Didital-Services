-- Run this only AFTER creating your own admin user in Supabase Authentication > Users.
-- Replace the email below with the exact email used for your admin login.
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
where email = 'YOUR_ADMIN_EMAIL@example.com';
-- Then sign out and sign back in to refresh the admin JWT.
