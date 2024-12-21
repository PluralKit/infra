#!/bin/sh

echo '{"cloudflare":{"TYPE":"CLOUDFLAREAPI","accountid":"'"$(op item get --vault=pluralkit --field=account_id cloudflare)"'","apitoken":"'"$(op item get --vault=pluralkit --field=dnscontrol_auth_token cloudflare --reveal)"'"}}'
