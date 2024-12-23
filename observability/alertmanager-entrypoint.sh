#!/bin/sh

fly6pn=$(grep fly-local-6pn /etc/hosts | awk '{print $1}')
echo "using $fly6pn as fly-local-6pn for bind"

envsubst < /alertmanager.template.yml > /alertmanager.yml

exec /bin/alertmanager \
	--cluster.listen-address=[$fly6pn]:9094 \
	--cluster.advertise-address=[$fly6pn]:9094 \
	--cluster.peer=pluralkit-alertmanager.internal:9094 \
	--config.file=/alertmanager.yml \
	--storage.path=/alertmanager
