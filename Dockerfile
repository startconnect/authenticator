# IMAGE BASE
FROM ubuntu:18.04

#######################
## START - VARIABLES ##
#######################

# ENABLE NO-INTERACTIVE MODE
ENV DEBIAN_FRONTEND=noninteractive

# DB
ENV DB_ENGINE=mysqli
ENV DB_HOST=localhost
ENV DB_PORT=3306
ENV DB_USER=freerad
ENV DB_PASS=freeradPass
ENV DB_NAME=radius

# DIR DOCUMENT ROOT APACHE
ENV DR=/var/www/html

# CONFIG DALO
ENV DALO_CFG=$DR/library/daloradius.conf.php

# DIR FREERADIUS CONFIG
ENV FR=/etc/freeradius/3.0

# MODULE FREERADIUS SQL
ENV FR_SQL=$FR/mods-available/sql

#####################
## END - VARIABLES ##
#####################

# UPDATE AND INSTALL PACKETS
RUN apt-get update -y && \
	apt-get install -y vim net-tools wget \
	freeradius freeradius-mysql freeradius-utils \
	mariadb-server \
	apache2 php libapache2-mod-php php-gd php-common php-mail \
	php-mail-mime php-mysql php-pear php-db php-mbstring php-xml php-curl

# DEFINE TIMEZONE
RUN ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

# FIX HELP TZDATA
RUN dpkg-reconfigure --frontend noninteractive tzdata

# MODIFY FREERADIUS TO SQL CONSULT
RUN sed -i "s/driver\ =\ \".*/driver\ =\ \"rlm_sql_mysql\"/" $FR_SQL
RUN sed -i "s/dialect\ =\ \".*/dialect\ =\ \"mysql\"/" $FR_SQL

# INFO CONNECTION DATABASE
RUN sed -i "s/\#.*server = \".*/\tserver = \"$DB_HOST\"/" $FR_SQL
RUN sed -i "s/\#.*port = .*/\tport = $DB_PORT/" $FR_SQL
RUN sed -i "s/\#.*login = \".*/\tlogin = \"$DB_USER\"/" $FR_SQL
RUN sed -i "s/\#.*password = \".*/\tpassword = \"$DB_PASS\"/" $FR_SQL
RUN sed -i "s/\#.*radius_db = \".*/\tradius_db = \"$DB_NAME\"/" $FR_SQL

# ENABLE READ_CLIENTS
RUN sed -i "s/\#.*read_clients = .*/\tread_clients = yes/" $FR_SQL

# ACTIVE MODULE SQL FOR FREERADIUS
RUN ln -sf $FR_SQL $FR/mods-enabled/

# FIX PERMISSIONS
RUN chown -R freerad:freerad $FR_SQL
RUN chown -R freerad:freerad $FR/mods-enabled/sql

# START SERVICE MYSQL
RUN service mysql start && mysql --user="root" --execute="CREATE DATABASE radius; GRANT ALL ON $DB_NAME.* TO $DB_USER@$DB_HOST IDENTIFIED BY '$DB_PASS'; flush privileges;"

# DOWNLOAD DALORADIUS
RUN wget http://sourceforge.net/projects/daloradius/files/latest/daloradius -O /tmp/daloradius.tar.gz

# EXTRACT
RUN tar -zxvf /tmp/daloradius.tar.gz -C /usr/local/src/

# REMOVE DR AND MOVE DALORADIUS
RUN rm -r $DR && mv /usr/local/src/daloradius* $DR

# CONFIG CONNECT DATABASE DALORADIUS
RUN sed -i "s/.*CONFIG_DB_ENGINE.*/\$configValues['CONFIG_DB_ENGINE'] = '$DB_ENGINE';/" $DALO_CFG
RUN sed -i "s/.*CONFIG_DB_HOST.*/\$configValues['CONFIG_DB_HOST'] = '$DB_HOST';/" $DALO_CFG
RUN sed -i "s/.*CONFIG_DB_PORT.*/\$configValues['CONFIG_DB_PORT'] = '$DB_PORT';/" $DALO_CFG
RUN sed -i "s/.*CONFIG_DB_USER.*/\$configValues['CONFIG_DB_USER'] = '$DB_USER';/" $DALO_CFG
RUN sed -i "s/.*CONFIG_DB_PASS.*/\$configValues['CONFIG_DB_PASS'] = '$DB_PASS';/" $DALO_CFG
RUN sed -i "s/.*CONFIG_DB_NAME.*/\$configValues['CONFIG_DB_NAME'] = '$DB_NAME';/" $DALO_CFG

# FIX OWNER DR
RUN chown www-data:www-data $DR -R 

# FIX PERMISSION CONFIG FILE
RUN chmod 644 $DALO_CFG

# IMPORT SCHEMA FREERADIUS IN MYSQL
RUN service mysql start && mysql -u root radius < $FR/mods-config/sql/main/mysql/schema.sql && mysql -u root radius < $DR/contrib/db/fr2-mysql-daloradius-and-freeradius.sql && mysql -u root radius < $DR/contrib/db/mysql-daloradius.sql

# PORTS EXPORTS
EXPOSE 80/tcp 443/tcp 1812/udp 1813/udp

# COPY SCRIPT START SERVICES
COPY ./start_services /usr/local/bin/

# WORKDIR
WORKDIR $DR

# START SERVICES
CMD ["start_services"]
