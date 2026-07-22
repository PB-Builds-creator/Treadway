// Cairn web app — connection settings.
// The publishable/anon key is SAFE to expose in a static site: every table is
// protected by row-level security, so it can only read/write the signed-in
// user's own rows.
window.CAIRN_CONFIG = {
  SUPABASE_URL: "https://bckcawaiyybrjsphiqdc.supabase.co",
  SUPABASE_ANON_KEY: "sb_publishable_cpBJDVV7v9Oqr1Z4K4CdYg_6qLsSQK_",
  // Web-push public key (safe to expose). Private key stays in the Supabase Edge Function.
  VAPID_PUBLIC_KEY: "BNEvMGCClT1cH8lUSzGvy8VgxI5doasaqB23hpYyXKsNK_hwMqMh7GJqVvDuuRHkuHrZRj6SlgoB0bbHCY0RCpw"
};
