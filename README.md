# Loris image server deployment for ARCHE

Important files

* `root/loris.conf`, especially the section with the resolver settings
* `root/loris-cron` - defines the cache pruning frequency and allowed cache size

## Adjustments made

* Own [resolver](https://github.com/loris-imageserver/loris/blob/development/doc/resolver.md) combining
  `SimpleFSResolver` serving data from `/tmp/static` with `SimpleHTTPResolver` serving data from
  ARCHE instances and capable of accessing data from a single selected ARCHE instance locally.
* Loris configuration tuned to support WEBP and GIF as source formats and WEBP as an output format.

## Debugging

* Apache/WSGI logs are in `/var/log/loris/`
* After the deployment sources used by the WSGI module are in `/opt/loris/venv/lib/python3.12/site-packages/loris`.
  * Especially the `loris.conf` is in `/opt/loris/venv/lib/python3.12/site-packages/loris/data/loris.conf`
  * After editing the Apache should be restarted with `supervisorctl restart apache2`
* For experimenting with file formats support:
  * create `/tmp/static/` directory owned by the `www-data:www-data` user/group
  * upload images into it
  * try out with `https://loris.acdh.oeaw.ac.at/{imageFileName}/full/full/0/default.jpg`
* When experimenting with the code you might need to disable the livenessProbe/readinessProbe/startupProbe
  of the cluster's workload (so the cluster doesn't restart the workload if something doesn't work for a moment)
