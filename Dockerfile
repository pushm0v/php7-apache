FROM php:7.3-apache
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
      libicu-dev \
      libpq-dev \
      libmcrypt-dev \
      zlib1g-dev \
      libzip-dev \
    && rm -r /var/lib/apt/lists/* \
    && docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd \
    && docker-php-ext-install \
      intl \
      mbstring \
      pcntl \
      pdo_mysql \
      pdo_pgsql \
      pgsql \
      zip \
      tokenizer \
      bcmath \
      opcache

# make sure custom log directories exist
RUN mkdir /usr/local/log; \
    mkdir /usr/local/log/apache2; \
    mkdir /usr/local/log/php; \
    chmod -R ug+w /usr/local/log

# create official PHP.ini file
RUN cp /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini

# update PECL and install xdebug, igbinary and redis w/ igbinary enabled
RUN pecl channel-update pecl.php.net; \
    pecl install xdebug-2.7.2; \
    pecl install redis; \
    docker-php-ext-enable xdebug \
    docker-php-ext-enable redis

RUN docker-php-ext-install sockets

# Delete the resulting ini files created by the PECL install commands
RUN rm -rf /usr/local/etc/php/conf.d/docker-php-ext-igbinary.ini;

# Add PHP config file to conf.d
RUN { \
        echo 'short_open_tag = Off'; \
        echo 'expose_php = Off'; \
        echo 'error_reporting = E_ALL & ~E_STRICT'; \
        echo 'display_errors = On'; \
        echo 'error_log = /usr/local/log/php/php_errors.log'; \
        echo 'upload_tmp_dir = /tmp/'; \
        echo 'allow_url_fopen = on'; \
        echo '[xdebug]'; \
        echo 'zend_extension="xdebug.so"'; \
        echo 'xdebug.remote_enable = 1'; \
        echo 'xdebug.remote_port = 9001'; \
        echo 'xdebug.remote_autostart = 1'; \
        echo 'xdebug.remote_connect_back = 0'; \
        echo 'xdebug.remote_host = host.docker.internal'; \
        echo 'xdebug.idekey = VSCODE'; \
    } > /usr/local/etc/php/conf.d/php-config.ini

# Manually set up the apache environment variables
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /usr/local/log/apache2

# Configure apache mods
RUN a2enmod rewrite

# Add ServerName parameter
RUN echo "ServerName localhost" | tee /etc/apache2/conf-available/servername.conf
RUN a2enconf servername

RUN mkdir -p /var/www/html/application/logs
RUN chmod 777 -R /var/www/html/application/logs

# Update the default apache site with the config we created.
RUN { \
        echo '<VirtualHost *:80>'; \
        echo '    ServerAdmin admin@example.com'; \
        echo '    DocumentRoot /var/www/html/public'; \
        echo '    <Directory /var/www/html>'; \
        echo '        Options Indexes FollowSymLinks MultiViews'; \
        echo '        AllowOverride All'; \
        echo '        Order deny,allow'; \
        echo '        Allow from all'; \
        echo '    </Directory>'; \
        echo '    ErrorLog /usr/local/log/apache2/error.log'; \
        echo '    CustomLog /usr/local/log/apache2/access.log combined' ; \
        echo '</VirtualHost>'; \
    } > /etc/apache2/sites-enabled/000-default.conf

EXPOSE 80

