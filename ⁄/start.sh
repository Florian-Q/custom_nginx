#!/bin/sh

# if [ -z "$DOMAINS" ]; then
#   echo "No domains set, you can use -e 'DOMAINS=example.com www.example.com'"
#   echo "to update server_name in conf.d/default.conf"
# fi

if [ $(find -L /etc/nginx/conf.d -type f | wc -l) -eq 0 ]; then
	echo "-- folder conf.d is empty, copy default file"
	mkdir -p "/etc/nginx/config/conf.d"
	cp -r /etc/nginx/config.default/conf.d/* /etc/nginx/config/conf.d
fi

if [ ! -f "/etc/nginx/config/nginx.conf" ]; then
	echo "-- nginx.conf not found, copy default file"
	mkdir -p "/etc/nginx/config"
	cp /etc/nginx/config.default/nginx.conf /etc/nginx/config/nginx.conf
	if [ ! -f "/etc/nginx/config/conf.d/main.conf" ]; then
		echo "-- conf.d/main.conf not found, copy default file"
		mkdir -p "/etc/nginx/config/conf.d"
		cp /etc/nginx/config.default/conf.d/* /etc/nginx/config/conf.d
	fi
fi

if [ ! -f "/etc/nginx/config/nginx_logrotate" ]; then
	echo "-- nginx_logrotate not found, copy default file" 
	cp /etc/nginx/config.default/nginx_logrotate /etc/nginx/config/nginx_logrotate
fi

exec "$@"