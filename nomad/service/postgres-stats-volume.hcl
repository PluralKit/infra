id        = "stats-pg-data"
name      = "stats-pg-data"
type      = "csi"
plugin_id = "seaweedfs"

# current db is 800mb, give it a bit of room
capacity_min = "2GiB"
capacity_max = "5GiB"

capability {
  access_mode     = "single-node-reader-only"
  attachment_mode = "file-system"
}

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type     = "ext4"
  mount_flags = ["rw"]
}
