id        = "glitchtip-appdata"
name      = "glitchtip-appdata"
type      = "csi"
plugin_id = "seaweedfs"

capacity_min = "1GiB"
capacity_max = "10GiB"

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type     = "ext4"
  mount_flags = ["rw"]
}

