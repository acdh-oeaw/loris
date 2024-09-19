# Loris image server deployment for ARCHE

Important files

* `root/loris.conf`, especially the section with the resolver settings
* `root/loris-cron` - defines the cache pruning frequency and allowed cache size

## Debugging

* Apache/WSGI logs are in `/var/log/loris/`
* After the deployment sources used by the WSGI module are in `/usr/local/lib/python3.8/dist-packages/loris`.
  After editing the Apache should be restarted with `supervisorctl restart apache2`
* For experimenting with file formats support:
  * create `/tmp/static/` directory owned by the `www-data:www-data` user/group
  * upload images into it
  * try out with `https://loris.acdh.oeaw.ac.at/{imageFileName}/full/full/0/default.jpg`
* When experimenting with the code you might need to disable the livenessProbe/readinessProbe/startupProbe
  of the cluster's workload (so the cluster doesn't restart the workload if something doesn't work for a moment)
