-- 061: explicit Data API table privileges for `authenticated` and
-- `service_role`.
--
-- Migrations 001–060 never GRANT table privileges: they rely on the
-- platform's default privileges, which on older Supabase projects gave
-- anon / authenticated / service_role full DML on every new table in
-- `public`. Newer Supabase stacks (e.g. the local stack from Supabase
-- CLI 2.113 used by .github/workflows/migrations.yml) no longer grant
-- that by default — tables come out with only TRUNCATE / REFERENCES /
-- TRIGGER for those roles. The schema then *applies* fine, but every
-- query from the app fails with "permission denied for table …",
-- including the service-role webhook path.
--
-- This migration makes the grants explicit. On a project that already
-- has them it is a no-op. Row access is still decided by RLS — every
-- table in `public` has RLS enabled (checked in supabase/ci/verify-
-- schema.sql), so a grant without a matching policy exposes nothing.
--
-- Deliberately NOT granted:
--   * anon — the app never reads tables before sign-in (auth goes
--     through GoTrue, invitations through SECURITY DEFINER RPCs).
--   * default privileges for future tables — new tables should grant
--     what they need in their own migration.
--
-- Hardening from earlier migrations is re-applied afterwards so this
-- broad grant can't undo it:
--   * 027 — clients may only UPDATE notifications.read_at.
--   * 054 — pending_message_statuses is service-role only.

GRANT SELECT, INSERT, UPDATE, DELETE
  ON ALL TABLES IN SCHEMA public
  TO authenticated, service_role;

GRANT USAGE, SELECT
  ON ALL SEQUENCES IN SCHEMA public
  TO authenticated, service_role;

-- Re-apply 027: column-level UPDATE only.
REVOKE UPDATE ON public.notifications FROM authenticated;
GRANT UPDATE (read_at) ON public.notifications TO authenticated;

-- Re-apply 054: internal buffer, never client-visible.
REVOKE ALL ON TABLE public.pending_message_statuses FROM anon, authenticated;
