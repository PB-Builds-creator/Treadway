# Scheduled reminders — canonical setup

The live implementation is `supabase/functions/send-reminders/index.ts`.
Do not copy a top-level function file; this repository keeps one canonical source.

Deploy from the repository root:

```bash
supabase functions deploy send-reminders --project-ref bckcawaiyybrjsphiqdc --no-verify-jwt --use-api
```

The function needs `VAPID_PUBLIC`, `VAPID_PRIVATE`, `VAPID_SUBJECT`, and
`CRON_SECRET` in Supabase Edge Function secrets. Never put their values in a
tracked file. Schedule the function with `cron-schedule.sql` only after replacing
`<CRON_SECRET>` inside the Supabase SQL Editor; do not save the real value here.

The consolidated product migration `cairn-product-upgrade.sql` must be applied
before partner nudges can be delivered. Regular task reminders continue to use
`reminders-schema.sql` and the same five-minute cron job.
