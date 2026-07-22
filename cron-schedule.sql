-- Cairn — schedule the reminder sender to run every 5 minutes.
-- Run this in the Supabase SQL Editor AFTER the send-reminders function is deployed
-- and its secrets are set. Safe to re-run (unschedule + reschedule).

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Remove any previous schedule with this name, then (re)create it.
select cron.unschedule('cairn-reminders')
where exists (select 1 from cron.job where jobname = 'cairn-reminders');

select cron.schedule(
  'cairn-reminders',
  '*/5 * * * *',
  $$
  select net.http_post(
    url := 'https://bckcawaiyybrjsphiqdc.supabase.co/functions/v1/send-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', '<CRON_SECRET>'
    )
  );
  $$
);

-- To check it's scheduled:   select * from cron.job;
-- To stop reminders later:   select cron.unschedule('cairn-reminders');
