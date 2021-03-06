#!/bin/bash
apt-get update -y

# install PHP and MySQL
apt-get install git nginx -y
systemctl enable nginx.service

apt-get install mariadb-server mariadb-client -y
systemctl enable mariadb.service

apt-get install php php-fpm php-mysql php-curl php-gd php-pear php-imagick php-imap php-mcrypt php-recode php-tidy php-xmlrpc -y

export DB_NAME=wordpress
export DB_USER=wordpress
export DB_PWD=password


#Fetch Worpdress website
rm -rf /var/www/html/*

cd /tmp
rm -rf /tmp/ufo-wordpress

git clone  https://github.com/pierreg256/ufo-wordpress.git
cp -R /tmp/ufo-wordpress/* /var/www/html/


chown -R www-data:www-data /var/www/html/
chmod -R 755 /var/www/html/

curl https://raw.githubusercontent.com/pierreg256/ubuntu-bootstrap-4-wp/master/default -o /etc/nginx/sites-available/default

cat > /etc/nginx/sites-available/default.manual << EOF
# Default server configuration
#
server {
        listen 80 default_server;
	listen [::]:80 default_server;

	# SSL configuration
	#
	# listen 443 ssl default_server;
	# listen [::]:443 ssl default_server;
	#
	# Self signed certs generated by the ssl-cert package
	# Don't use them in a production server!
	#
	# include snippets/snakeoil.conf;

	root /var/www/html;

	# Add index.php to the list if you are using PHP
	index index.php index.html index.htm index.nginx-debian.html;

	server_name _;

	location / {
	     # First attempt to serve request as file, then
	     # as directory, then fall back to displaying a 404.
	     try_files $uri $uri/ =404;
	}

	# pass PHP scripts to FastCGI server
	#
	location ~ \.php$ {
	     include snippets/fastcgi-php.conf;

	#       # With php-fpm (or other unix sockets):
	        fastcgi_pass unix:/var/run/php/php7.0-fpm.sock;
	#       # With php-cgi (or other tcp sockets):
	#       fastcgi_pass 127.0.0.1:9000;
	}

        # deny access to .htaccess files, if Apache's document root
        # concurs with nginx's one
        #
        #location ~ /\.ht {
        #       deny all;
        #}
}
EOF

systemctl restart nginx.service
systemctl stop apache2.service
systemctl disable apache2.service

################################

# Start MySQL
systemctl start mariadb.service

# Setup Password and create database
mysqladmin -u root password "$DB_PWD"

mysql -u root --password="$DB_PWD" << EOF
   DROP DATABASE IF EXISTS $DB_NAME;
   CREATE DATABASE $DB_NAME;
   CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PWD';
   GRANT ALL ON wordpress.* TO '$DB_USER'@'localhost';
   FLUSH PRIVILEGES;
EOF

curl https://raw.githubusercontent.com/pierreg256/ubuntu-bootstrap-4-wp/master/wordpress.sql | mysql -u $DB_USER -p $DB_NAME --password="$DB_PWD"


WP_URL=`curl -H Metadata:true "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2017-04-02&format=text"`
mysql -u $DB_USER -p $DB_NAME --password="$DB_PWD" -e "UPDATE wp_options SET option_value='$WP_URL' WHERE option_name='siteurl' OR option_name='home'"

