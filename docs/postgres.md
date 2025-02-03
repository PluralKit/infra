# Postgres databases

PluralKit runs two PostgreSQL databases: `data` and `messages`.

`data` is the main datastore for PluralKit. It is ~45GB on disk, most of it is cached in RAM (todo: all of it should be cached in RAM, how do we get postgres to do that?)

`messages`, ~400gb on disk, contains one multi-billion row table for message history. It is split off from `data` so the postgres cache can be filled with useful data instead of old messages.
<br>Because of the size of this database, any operator activity (migrations, manual queries across wide amounts of data) is quite slow and discouraged if possible.
<br>todo: at least that's the case on hetzner, try with our own hardware

They are both backed up by WAL streaming with [wal-g](https://github.com/wal-g/wal-g), to a Cloudflare R2 bucket since Backblaze B2 is not quite compatible.)

Basebackups and backup testing is done manually once in a while. (this isn't great, we should do this regularly)

## Setting up a replica from backups

This is a good way to test backups, or to migrate to a new database server with little downtime.

Warning: you will need a lot of space to do this - maybe 1.5x the space taken up by the existing database.

Steps:
- run a basebackup on the current primary: `wal-g backup-push`
- restore it into the new server: `wal-g backup-fetch`
- `touch standby.signal` in the new data-dir
- update postgresql.conf with the new server info (`database.nix` does this for you, but for a test server you're probably not using nixos configs)
- launch postgres with a replica connection (search for `primary-conninfo` in `database.nix`)
- wait until the replication process finishes and the db is caught up

This takes ~15m for data postgres and ~1h30 for messages (70m for basebackup, 20m restore). todo: can we speed up basebackups somehow?
<br>Costs $0.50 on Vultr with a pretty big VM (32gb ram / 640gb storage).

Finally: clean up the R2 bucket with `wal-g delete retain FIND_FULL 1`. (This takes a while)

Remember to delete the Vultr VM if this was just a test restore.
