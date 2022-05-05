#!/bin/bash

chown -R loris:loris /usr/local/share/images /var/log/loris /var/cache/loris /tmp/loris

exec "$@"
