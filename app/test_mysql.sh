#!/bin/sh
# wait-for-postgres.sh

set -e

DB_USER=$1
DB_PASSWORD=$2
CMD=$3

until /usr/bin/mysql -u $DB_USER -h db --password=$DB_PASSWORD -e 'use test; select count(*) from users;'; do
  >&2 echo "Mysql is unavailable - sleeping"
  sleep 1
done

>&2 echo "Mysql is up - we can continue"
${CMD}
