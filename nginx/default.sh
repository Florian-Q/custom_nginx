#!/bin/sh

# if [ -z "$DOMAINS" ]; then
#   echo "No domains set, you can use -e 'DOMAINS=example.com www.example.com'"
#   echo "to update server_name in conf.d/default.conf"
# fi

if [ ! "$(ls -A /etc/nginx/conf.d)" ]; then
	echo "-- folder conf.d is empty, copy default file" 
	cp /etc/nginx/conf.d.default/* /etc/nginx/conf.d/
fi

exec "$@"