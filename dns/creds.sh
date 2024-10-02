#!/bin/sh

echo '{"hedns":{"TYPE":"HEDNS","username":"'"$(op item get he.net --field username)"'","password":"'"$(op item get he.net --field password)"'"}}'
