#!/bin/sh

op item get mmpg5s3r3ffaatoz2k3wi5f3cy --format json | jq '{
  cloudflare: {
    TYPE: "CLOUDFLAREAPI",
    accountid: (.fields[] | select(.label == "account_id") | .value),
    apitoken: (.fields[] | select(.label == "dnscontrol_auth_token") | .value)
  }
}'
