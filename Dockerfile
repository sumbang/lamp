FROM debian:jessie
MAINTAINER lioshi <lioshi@lioshi.com>

# Tweaks to give MySQL write permissions to the app
#ENV BOOT2DOCKER_ID 1000
#ENV BOOT2DOCKER_GID 50
#
#RUN useradd -r mysql -u ${BOOT2DOCKER_ID} && \
#    usermod -G staff mysql
#
#RUN groupmod -g $(($BOOT2DOCKER_GID + 10000)) $(getent group $BOOT2DOCKER_GID | cut -d: -f1)
#RUN groupmod -g ${BOOT2DOCKER_GID} staff

# Install packages
ENV DEBIAN_FRONTEND noninteractive
RUN mkdir -p /var/cache/apt/archives/partial
RUN touch /var/cache/apt/archives/lock
RUN chmod 640 /var/cache/apt/archives/lock
RUN apt-get clean && apt-get update
#RUN apt-get update --fix-missing

# PHP5 lamp version
# RUN apt-get -y install supervisor apt-utils git apache2 lynx libapache2-mod-php5 php5-dev mysql-server php5-mysql php5-curl php5-gd pwgen php5-mcrypt php5-intl php5-imap vim graphviz parallel cron jpegoptim optipng locales


# PHP7 lamp version
RUN apt-get -y install apt-transport-https lsb-release ca-certificates
RUN apt-get -y install wget
RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
RUN echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
RUN apt-get update
RUN apt-get -y install --no-install-recommends supervisor apt-utils git apache2 lynx mysql-server pwgen php7.1 libapache2-mod-php7.1 php7.1-mysql php7.1-curl php7.1-json php7.1-gd php7.1-mcrypt php7.1-msgpack php7.1-memcached php7.1-intl php7.1-sqlite3 php7.1-gmp php7.1-geoip php7.1-mbstring php7.1-redis php7.1-xml php7.1-zip php7.1-imap vim graphviz parallel cron jpegoptim optipng locales


#Install   v8js
RUN apt-get -y install build-essential python libglib2.0-dev
RUN cd /tmp && git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
ENV PATH=${PATH}:/tmp/depot_tools
RUN cd /tmp && fetch v8 --no-history 
RUN cd /tmp/v8/ && tools/dev/v8gen.py -vv x64.release -- is_component_build=true && ninja -C out.gn/x64.release/ && mkdir -p /opt/v8/lib && mkdir -p /opt/v8/include && cp out.gn/x64.release/lib*.so out.gn/x64.release/*_blob.bin out.gn/x64.release/icudtl.dat /opt/v8/lib/ && cp -R include/* /opt/v8/include/
RUN cd /tmp && git clone https://github.com/phpv8/v8js.git
RUN apt-get update
RUN apt-get -y install php7.1-dev
RUN cd /tmp/v8js/ && phpize && ./configure --with-v8js=/opt/v8 && make && make test && make install
RUN echo "extension=v8js.so" >> /etc/php/7.1/apache2/php.ini


#Install imagick
RUN apt-get -y install imagemagick php7.1-imagick 
RUN apt-get -y install libapache2-mod-xsendfile 

# Apache2 conf
RUN echo "# Include vhost conf" >> /etc/apache2/apache2.conf 
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf 
RUN echo "IncludeOptional /data/lamp/conf/*.conf" >> /etc/apache2/apache2.conf 
RUN echo "<Directory /data/lamp/www> " >> /etc/apache2/apache2.conf 
RUN echo "    Options Indexes FollowSymLinks Includes ExecCGI" >> /etc/apache2/apache2.conf 
RUN echo "    AllowOverride None" >> /etc/apache2/apache2.conf 
RUN echo "    Require all granted" >> /etc/apache2/apache2.conf 
RUN echo "</Directory>" >> /etc/apache2/apache2.conf 

# Timezone settings
ENV TIMEZONE="Europe/Paris"
RUN echo "date.timezone = '${TIMEZONE}'" >> /etc/php/7.1/apache2/php.ini && \
  echo "${TIMEZONE}" > /etc/timezone && dpkg-reconfigure --frontend noninteractive tzdata

RUN sed -i -e 's/# fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen && \
    echo 'LANG="fr_FR.UTF-8"'>/etc/default/locale && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=fr_FR.UTF-8
ENV LANG fr_FR.UTF-8 
ENV LC_ALL fr_FR.UTF-8  

# Add image configuration and scripts
ADD start-apache2.sh /start-apache2.sh
ADD start-mysqld.sh /start-mysqld.sh
#ADD run.sh /run.sh
RUN chmod 755 /*.sh
ADD my.cnf /etc/mysql/conf.d/my.cnf
ADD supervisord-apache2.conf /etc/supervisor/conf.d/supervisord-apache2.conf
ADD supervisord-mysqld.conf /etc/supervisor/conf.d/supervisord-mysqld.conf

# Remove pre-installed database
RUN rm -rf /var/lib/mysql/*

# Add MySQL utils
ADD create_mysql_admin_user.sh /create_mysql_admin_user.sh
RUN chmod 755 /*.sh

# config Apache
RUN a2enmod rewrite

# Environment variables to configure php
ENV PHP_UPLOAD_MAX_FILESIZE 10M
ENV PHP_POST_MAX_SIZE 10M
ENV PHP_MEMORY_LIMIT 1024M

# Add dirs for manage sites (mount from host in run needeed for persistence)
RUN mkdir /data && mkdir /data/lamp && mkdir /data/lamp/conf && mkdir /data/lamp/www 

# Add dirs for mysql persistent datas
#RUN mkdir -p /var/lib/mysql
#RUN chmod -R 777 /var/lib/mysql
#RUN chown -R root:root /var/lib/mysql

RUN chown -R mysql:mysql /var/lib/mysql

# Add volumes for MySQL 
VOLUME  [ "/etc/mysql", "/var/lib/mysql" ]

# Add volumes for sites, confs and libs and mysql from host
# /data/lamp/conf : apache conf file
# /data/lamp/www  : site's file
VOLUME  ["/data"]

# Add alias
RUN echo "alias node='nodejs'" >> ~/.bashrc

# Add links
RUN ln -s /usr/bin/nodejs /usr/bin/node

# PHPMyAdmin
RUN (echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | debconf-set-selections)
RUN (echo 'phpmyadmin phpmyadmin/app-password password root' | debconf-set-selections)
RUN (echo 'phpmyadmin phpmyadmin/app-password-confirm password root' | debconf-set-selections)
RUN (echo 'phpmyadmin phpmyadmin/mysql/admin-pass password root' | debconf-set-selections)
RUN (echo 'phpmyadmin phpmyadmin/mysql/app-pass password root' | debconf-set-selections)
RUN (echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' | debconf-set-selections)
RUN apt-get install phpmyadmin -y
ADD configs/phpmyadmin/config.inc.php /etc/phpmyadmin/conf.d/config.inc.php
RUN chmod 755 /etc/phpmyadmin/conf.d/config.inc.php
ADD configs/phpmyadmin/phpmyadmin-setup.sh /phpmyadmin-setup.sh
#RUN chmod +x /phpmyadmin-setup.sh
#RUN /phpmyadmin-setup.sh

# Symfony 2 pre requisted
RUN apt-get -y install curl
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer


ADD run.sh /run.sh
RUN chmod 755 /*.sh

EXPOSE 80 3306

CMD ["/run.sh"]


