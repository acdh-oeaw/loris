# Loris image server

## Cache pruning

Currently we are pruning the cache every hour leaving no more than 2 GB of original (`/usr/local/share/images/`) and transformed (`/var/cache/loris/`) files cache (see `custom/cleanScripts`). The pruning is last access time based (what was accessed last is removed first). The allowed size is hardcoded in the scripts.

If the service will be used more extensively the 2 GB limit may become a bottleneck (images being used recently may not fit in the cache limit).
It would be nice to adjust the pruning script(s) so they read the limit from an environment variable.

What doesn't help is that Loris always assures the original image (which is likely big and occupies quite some storage) is cached locally and downloads it if it's missing. It's done even if the transformed version to be fetched by a given request is already in the cache and the original image isn't really needed to serve the request.
