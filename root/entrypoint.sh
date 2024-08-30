#!/bin/bash

chown -R www-data:www-data /var/log/loris /var/cache/loris /tmp/loris

exec "$@"
