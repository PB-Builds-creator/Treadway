# Security policy

## Supported version

Security fixes target the current `master` branch and the deployment at `https://cairn.surge.sh`.

## Reporting a vulnerability

Please do not open a public issue for a suspected vulnerability involving authentication, authorization, private user data, web push, or account deletion. Report it privately to **paxtonraithel@gmail.com** with:

- the affected page or component;
- clear reproduction steps;
- the likely impact;
- screenshots or logs with personal data removed.

Please allow a reasonable period for investigation and remediation before disclosure.

## Security boundaries

- Supabase Auth and Postgres Row Level Security are the remote-data security boundary.
- The per-device PIN is a convenience lock, not a substitute for account security or device encryption.
- `Web/config.js` contains a browser-safe Supabase publishable key. Private keys, service-role credentials, and cron secrets must never be stored in `Web/` or committed.
- Partner features expose only the narrow fields described in the privacy policy; tasks and journal content are not partner-readable.
- No production data, credentials, or account identifiers belong in issues, pull requests, fixtures, or screenshots.
