id        = "glitchtip-postgres-data"
name      = "glitchtip-postgres-data"
type      = "csi"
plugin_id = "seaweedfs"

capacity_min = "1GiB"
capacity_max = "10GiB"

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
