#! /usr/bin/env python3

import argparse
import csv
import json
import io
import subprocess
import sys

DEFAULT_POSTGRES_URI = 'postgres://:5434/messages'

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

def parse_args():
    parser = argparse.ArgumentParser(prog='pk-messagedump', description="Dump message metadata for the given sender(s) by Discord account snowflake")
    parser.add_argument('accounts', metavar='SNOWFLAKE', nargs='+', action='extend', type=str, help='Discord account snowflakes')
    parser.add_argument('--postgres-uri', dest='postgres_uri', default=DEFAULT_POSTGRES_URI)
    parser.add_argument('-f', '--format', dest='format', choices=['csv', 'json', 'jsonc', 'links'], default='csv', help='output format')
    parser.add_argument('-o', '--output', dest='output', default='-', help="output file (use '-' for stdout)")
    return parser.parse_args()

def capture_from_psql(accounts, postgres_uri):
    snowflakes = ','.join([f"'{snowflake}'" for snowflake in accounts])
    sql = f"COPY (SELECT sender, mid, original_mid, guild, channel FROM messages WHERE sender IN ({snowflakes})) TO STDOUT (FORMAT csv, HEADER 1, DELIMITER ',');"

    output = subprocess.run(['psql', postgres_uri], input=sql, capture_output=True, text=True)
    output.check_returncode()

    reader = csv.DictReader(io.StringIO(output.stdout))
    return [x for x in reader]

def main(args):
    data = capture_from_psql(args.accounts, args.postgres_uri)
    if len(data) == 0:
        eprint('no data captured, bailing')
        return 1

    output = sys.stdout
    if args.output != '-':
        output = open(args.output, 'w', newline='')

    try:
        if args.format == 'csv':
            writer = csv.DictWriter(output, data[0].keys())
            writer.writeheader()
            for row in data:
                writer.writerow(row)

        elif args.format == 'json':
            json.dump(data, output, sort_keys=True, indent=4)

        elif args.format == 'jsonc':
            json.dump(data, output, sort_keys=True, separators=(',', ':'))

        elif args.format == 'links':
            for row in data:
                rowurl = "https://discord.com/channels/{guild}/{channel}/{mid}".format(**row)
                print(rowurl, file=output, end='\n')

        else:
            eprint(f"error: unknown format: {args.format}")
            return 1

    finally:
        if args.output != '-':
            output.close()

    return 0

if __name__ == "__main__":
    args = parse_args()
    exit(main(args))
