# verify-google-play Edge Function

This Edge Function verifies Google Play purchase tokens and forwards verified
metadata to the Supabase RPC `activate_license_from_iap`.

Environment variables required:

- `SUPABASE_URL` — your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` — service role key (keep secret in Edge env)
- `GOOGLE_SERVICE_ACCOUNT_KEY` — JSON string of Google service account key
- `ANDROID_PACKAGE_NAME` — Android package name (e.g. com.example.tailorpro)

Important:
- Replace the JWT signing placeholder in `index.ts` with a proper RS256 JWT
  creation using the service account `private_key` before deploying to production.
- Keep `SUPABASE_SERVICE_ROLE_KEY` and `GOOGLE_SERVICE_ACCOUNT_KEY` secret.

Deployment:
1. Deploy the function to Supabase Edge Functions.
2. Set the environment variables in the function settings.
3. Test using a valid Google Play purchase token from a test account.
