#!/bin/bash
# - Install GLPI if not already installed
# - Run apache in foreground

export APACHE_DIR=${APACHE_DIR:-"/var/www/html"}
export APACHE_GLPI_DIR=${APACHE_GLPI_DIR:-"${APACHE_DIR}/glpi"}

export GLPI_DB_CONF_DIR=${GLPI_CONF_DIR:-"${APACHE_GLPI_DIR}/config"}
export GLPI_DB_CONF_FILE=${GLPI_DB_CONF_FILE:-"${GLPI_DB_CONF_DIR}/config_db.php"}

export GLPI_VERSION=${GLPI_VERSION:-"9.1.6"}
#export GLPI_SOURCE_URL=${GLPI_SOURCE_URL:-"https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz"}
#export GLPI_SOURCE_URL=${GLPI_SOURCE_URL:-"https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tar.gz"}
export GLPI_SOURCE_URL=${GLPI_SOURCE_URL:-"https://github.com/glpi-project/glpi/archive/${GLPI_VERSION}.tar.gz"}

export GLPI_MYSQL_HOST=${GLPI_MYSQL_HOST:-"localhost"}
export GLPI_MYSQL_USER=${GLPI_MYSQL_USER:-"glpi"}
export GLPI_MYSQL_PASS=${GLPI_MYSQL_PASS:-"glpipass"}
export GLPI_MYSQL_DB=${GLPI_MYSQL_DB:-"glpi"}

export APACHE_CONF=${APACHE_CONF:-"/etc/apache2/sites-available/000-default.conf"}

MYID=$(id)
APACHEID=$(su www-data -s /bin/bash -c id)
echo "  Running user ids is: ${MYID}"
echo "  www-data user ids is: ${APACHEID}"
echo "-----------> End enviroment show..."

### INSTALL GLPI IF NOT INSTALLED ALREADY ######################################

if [ "$(ls -A ${APACHE_GLPI_DIR})" ]; then
  echo "-----------> GLPI is already installed at ${APACHE_GLPI_DIR}"

echo "-----------> Verificando se existe e criando arquivo de configuração do bd"
[ -d ${GLPI_DB_CONF_DIR} ] || mkdir -p --verbose ${GLPI_DB_CONF_DIR}
[ -f ${GLPI_DB_CONF_FILE} ] || touch $GLPI_DB_CONF_FILE

# Método abaixo grava os valores diretamente no arquivo de configuração do GLPI
# \ faz com que o valor de $var não seja convertido
#
cat > /tmp/config_db.tmp << EOF
<?php
 class DB extends DBmysql {
  var \$dbhost = '${GLPI_MYSQL_HOST}';
  var \$dbuser = '${GLPI_MYSQL_USER}';
  var \$dbpassword = '${GLPI_MYSQL_PASS}';
  var \$dbdefault = '${GLPI_MYSQL_DB}';
 }
?>
EOF

chown www-data /tmp/config_db.tmp
runuser -u www-data cp /tmp/config_db.tmp $GLPI_DB_CONF_FILE



else
  echo '-----------> Install GLPI ${GLPI_VERSION}'
  echo "Using ${GLPI_SOURCE_URL}"
  mkdir -p $APACHE_GLPI_DIR
  wget -O /tmp/glpi.tar.gz $GLPI_SOURCE_URL --no-check-certificate
  tar xzvf /tmp/glpi.tar.gz -C $APACHE_GLPI_DIR --strip-components 1
  cd $APACHE_GLPI_DIR
  composer install --no-dev
  chown -R www-data.www-data ${APACHE_GLPI_DIR}
  rm /tmp/glpi.tar.gz
fi


### CREATING SSL CERTS ######################################################
#
# https://www.shellhacks.com/create-csr-openssl-without-prompt-non-interactive/
#
# openssl req	certificate request generating utility
# -nodes	if a private key is created it will not be encrypted
# -newkey	creates a new certificate request and a new private key
# rsa:2048	generates an RSA key 2048 bits in size
# -keyout	the filename to write the newly created private key to
# -out	specifies the output filename
# -subj	sets certificate subject
# /C=	Country	GB
# /ST=	State	London
# /L=	Location	London
# /O=	Organization	Global Security
# /OU=	Organizational Unit	IT Department
# /CN=	Common Name	example.com

echo "-----------> Gerando novos certificados privados para o HTTPS"

mkdir -p /etc/apache2/ssl
openssl req -new -x509 -days 36500 -keyout /etc/apache2/ssl/myssl.key -out /etc/apache2/ssl/myssl.crt -nodes -subj '/C=BR/L=Brazil/O=VirtualHost Website Company/OU=Virtual Host Website department/CN=${HOSTNAME}'



### CONFIG APACHE ######################################
## APACHE DOCS: https://httpd.apache.org/docs/2.4/


echo "-----------> Criando arquivo de configuração do apache"

cat > $APACHE_CONF << EOF
ServerName ${HOSTNAME}
AddDefaultCharset UTF-8

LogFormat "%v:%p %h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" vhost_combined
LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" combined-default
LogFormat "%h %l %u %t \"%r\" %>s %O" common
LogFormat "%{Referer}i -> %U" referer
LogFormat "%{User-agent}i" agent
LogFormat "%h %l %t \"%r\" %>s %b \"%{User-agent}i\"" combined

<FilesMatch "^\.ht">
        Require all denied
</FilesMatch>

<DirectoryMatch "/\.svn">
   Require all denied
</DirectoryMatch>

<DirectoryMatch "/\.git">
   Require all denied
</DirectoryMatch>

<Directory />
	Options none
    AllowOverride None
    Require all denied
</Directory>

<Location /server-status>
       SetHandler server-status
       Require local
      #Require ip 192.0.2.0/24
</Location>


# Setting this header will prevent other sites from embedding pages from this
# site as frames. This defends against clickjacking attacks.
# Requires mod_headers to be enabled.
#
# Header set X-Frame-Options: "sameorigin"

# Set to one of:  Full | OS | Minimal | Minor | Major | Prod
ServerTokens Minimal

# Set to one of:  On | Off | EMail
ServerSignature Off

<Directory ${APACHE_GLPI_DIR}>
 	Options -Indexes -FollowSymLinks +MultiViews -ExecCGI -Includes +SymLinksIfOwnerMatch
 	AllowOverride All
	#Require all denied
	Require all granted
</Directory>

<Directory /var/www/html/glpi/config>
    Options -Indexes
    Require all denied
</Directory>
<Directory /var/www/html/glpi/files>
    Options -Indexes
    Require all denied
</Directory>

<VirtualHost *:80>
	ServerAdmin localhost
	DocumentRoot ${APACHE_GLPI_DIR}
	DirectoryIndex index.php index.html
	ServerAlias *
	#ServerName *
	#ErrorLog /var/log/apache2/error-${HOSTNAME}.log
	#CustomLog /var/log/apache2/access-${HOSTNAME}.log combined
	ErrorLog /dev/stdout
	#CustomLog /dev/stdout combined
</VirtualHost>

<VirtualHost *:443>
	ServerAdmin localhost
	DocumentRoot ${APACHE_GLPI_DIR}
	DirectoryIndex index.php index.html
	ErrorLog /dev/stdout

	SSLEngine On
	SSLCertificateFile /etc/apache2/ssl/myssl.crt
	SSLCertificateKeyFile /etc/apache2/ssl/myssl.key
	
	<Location />
		SSLRequireSSL On
		SSLVerifyClient optional
		SSLVerifyDepth 1
		SSLOptions +StdEnvVars +StrictRequire
	</Location>
</VirtualHost>
EOF




### RUN APACHE IN FOREGROUND ###################################################

# service apache2 restart
# tail -f /var/log/apache2/error.log -f /var/log/apache2/access.log

#echo "-----------> Fixing permissions"
#chown -R www-data.www-data ${APACHE_GLPI_DIR}

echo "-----------> Habilitando modulos rewrite e ssl"

source /etc/apache2/envvars

a2enmod php7.0
a2dismod userdir
a2enmod rewrite
a2enmod ssl

echo "-----------> Iniciando Apache"
/usr/sbin/apache2ctl -DFOREGROUND -e debug

