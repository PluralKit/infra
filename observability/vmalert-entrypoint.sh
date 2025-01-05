#!/bin/sh

exec /usr/local/bin/vmalert-prod \
		-rule=/vmalert.yml \
		-enableTCP6 \
		-datasource.url=http://vm.svc.pluralkit.net/select/0/prometheus/ \
		-notifier.url=http://alerts.svc.pluralkit.net \
		-remoteWrite.url=http://vm.svc.pluralkit.net/insert/0/prometheus/ \
		-remoteRead.url=http://vm.svc.pluralkit.net/select/0/prometheus/

		# must not have labels for high availability
		# -external.label=fly_machine-id=$FLY_MACHINE_ID
