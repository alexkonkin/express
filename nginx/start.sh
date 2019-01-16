#!/bin/sh

envsubst '${IP_EXT}' < /etc/nginx/nginx.tmpl > /etc/nginx/nginx.conf

exec /usr/sbin/nginx -g 'daemon off;'

