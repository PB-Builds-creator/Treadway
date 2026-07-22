#!/bin/bash
# Cairn — one-shot reminder deploy. Run this once in Terminal:
#     bash /Users/paxton/Cairn/deploy-reminders.sh
# A browser window opens for you to click "Authorize" — that's the only interaction.
set -e
REF="bckcawaiyybrjsphiqdc"
cd /Users/paxton/Cairn

echo ""
echo "──────────────────────────────────────────────"
echo " Step 1 of 3:  Log in to Supabase"
echo " A browser window will open. Click 'Authorize'."
echo "──────────────────────────────────────────────"
supabase login

echo ""
echo " Step 2 of 3:  Deploying the reminder function…"
supabase functions deploy send-reminders --project-ref "$REF" --no-verify-jwt --use-api

echo ""
echo " Step 3 of 3:  Setting the secret keys…"
supabase secrets set --project-ref "$REF" \
  VAPID_PUBLIC=BNEvMGCClT1cH8lUSzGvy8VgxI5doasaqB23hpYyXKsNK_hwMqMh7GJqVvDuuRHkuHrZRj6SlgoB0bbHCY0RCpw \
  VAPID_PRIVATE=Alro-mfxXjYJw-7uexP5PWzxDpt25qg9PZwKnShx478 \
  VAPID_SUBJECT=mailto:paxtonraithel@gmail.com \
  CRON_SECRET=a83391ff4fce91e1526a26f6adfa8d1acc21d1c2941f7836

echo ""
echo "=================================================="
echo " ✅ Done. Now tell Claude: \"deployed\""
echo "=================================================="
