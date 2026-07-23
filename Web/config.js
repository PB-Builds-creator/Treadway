// Treadway web app — connection settings. CAIRN_CONFIG stays for device compatibility.
// The publishable/anon key is SAFE to expose in a static site: every table is
// protected by row-level security, so it can only read/write the signed-in
// user's own rows.
window.CAIRN_CONFIG = {
  SUPABASE_URL: "https://bckcawaiyybrjsphiqdc.supabase.co",
  SUPABASE_ANON_KEY: "sb_publishable_cpBJDVV7v9Oqr1Z4K4CdYg_6qLsSQK_",
  // Web-push public key (safe to expose). Private key stays in the Supabase Edge Function.
  VAPID_PUBLIC_KEY: "BMFCBUWsXSfKfX-VL_jh4-s8J2EB_hysNXYH5vQ9-seRffWA-pDnF9nyHOkBa7-syu7lTQO8INxUm4LxKmmrPvU"
};
