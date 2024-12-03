#!/usr/bin/env python3

import argparse
import csv
import json
import io
import os
import random
import string
import subprocess
import sys
import urllib.request

DEFAULT_POSTGRES_URI = 'postgres://pluralkit:@db.svc.pluralkit.net:5432/pluralkit'

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

def capture_from_psql(query):
    sql = f"COPY ({query}) TO STDOUT (FORMAT csv, HEADER 1, DELIMITER ',');"

    output = subprocess.run(['psql', DEFAULT_POSTGRES_URI], input=sql, capture_output=True, text=True)
    output.check_returncode()

    reader = csv.DictReader(io.StringIO(output.stdout))
    return [x for x in reader]

def main():
    q = "SELECT hid, uuid, webhook_url, webhook_token from systems where webhook_url is not null"
    if len(sys.argv) > 1:
        hid = sys.argv[1]
        if len(hid) == 5:
            hid += ' '
        q += f" and hid = '{hid}'"
    print(q)
    data = capture_from_psql(q)

    for system in data:
        ok_data = {'type':'PING','signing_token':system['webhook_token'],'system_id':system['uuid'].strip()}
        bad_data = {'type':'PING','signing_token':''.join(random.choice(string.ascii_lowercase) for i in range(64)),'system_id':system['uuid'].strip()}

        payload = {'auth':os.environ['DISPATCH_TOKEN'],'url':system['webhook_url'],'payload':json.dumps(ok_data),'test':json.dumps(bad_data)}
        try:
            res = urllib.request.urlopen(urllib.request.Request('http://dispatch.svc.pluralkit.net', data=bytes(json.dumps(payload), 'UTF-8'), headers={'content-type':'application/json'}))
            body = res.fp.read()
            print(f"system {system['hid']} at {system['webhook_url']}: {body}")
        except Exception as e:
            print(f"failed to req {system}: {e}")

    return 0

if __name__ == "__main__":
    exit(main())
