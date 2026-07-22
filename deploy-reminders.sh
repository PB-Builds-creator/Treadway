#!/bin/bash
# Cairn — deploy the canonical reminder function.
# Production secrets are configured separately in Supabase and must never be
# written into this tracked helper.
set -euo pipefail

REF="bckcawaiyybrjsphiqdc"
cd /Users/paxton/Cairn

supabase functions deploy send-reminders \
  --project-ref "$REF" \
  --no-verify-jwt \
  --use-api

echo "Reminder function deployed. Confirm required secrets in Supabase before scheduling cron."
