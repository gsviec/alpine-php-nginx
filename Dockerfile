FROM php:7.4-fpm-alpine
LABEL Maintainer="Tim de Pater <hello@gsviec.com>" \
      Description="Lightweight container with Nginx 1.16 & PHP-FPM 7.3 based on Alpine Linux."

# Add repos
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

# Add basics first
RUN apk update && apk upgrade && apk add \
	bash curl ca-certificates openssl openssh git nano libxml2-dev tzdata icu-dev openntpd libedit-dev libzip-dev \
        supervisor

RUN docker-php-ext-install pdo_mysql soap zip pcntl  sockets intl exif

RUN apk add php7-pecl-redis

# Add Composer
RUN curl -sS https://getcomposer.org/installer | php && mv composer.phar /usr/local/bin/composer

RUN apk add nginx npm
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY config/php.ini /etc/php7/conf.d/zzz_custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R www-data.www-data /run && \
  chown -R www-data.www-data /var/lib/nginx && \
  chown -R www-data.www-data /var/log/nginx

# Setup document root
RUN mkdir -p /var/www/html

# Make the document root a volume
VOLUME /var/www/html

# Switch to use a non-root user from here on
USER www-data

# Add application
WORKDIR /var/www/html
COPY --chown=www-data src/ /var/www/html/

# Expose the port nginx is reachable on
EXPOSE 8080

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping
