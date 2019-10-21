#!/bin/sh
# wait-for-postgres.sh

set -e

until /usr/bin/mysql -u root -h db --password=test -e 'use test; select count(*) from users;'; do
  >&2 echo "Mysql is unavailable - sleeping"
  sleep 1
done

>&2 echo "Mysql is up - executing command"
exit 0
