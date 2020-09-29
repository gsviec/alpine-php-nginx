FROM php:7.4-fpm-alpine
LABEL Maintainer="Thien Tran <hello@gsviec.com>" \
      Description="Lightweight container with Nginx 1.16 & PHP-FPM 7.4 based on Alpine Linux."

# Add repos
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

# Add basics first
RUN apk update && apk upgrade && apk add \
	bash curl ca-certificates openssl openssh git nano libxml2-dev tzdata icu-dev openntpd libedit-dev libzip-dev \
        supervisor aspell-libs aspell-dev autoconf gcc g++ make

RUN docker-php-ext-install pdo_mysql soap pspell zip pcntl  sockets intl exif simplexml soap xml

# install redis
RUN pecl install -o -f redis \
&&  rm -rf /tmp/pear \
&&  docker-php-ext-enable redis

# Add Composer
RUN curl -sS https://getcomposer.org/installer | php && mv composer.phar /usr/local/bin/composer
ARG PSR_VERSION=1.0.0
ARG PHALCON_VERSION=4.0.5
ARG PHALCON_EXT_PATH=php7/64bits

RUN set -xe && \
        # Download PSR, see https://github.com/jbboehr/php-psr
        curl -LO https://github.com/jbboehr/php-psr/archive/v${PSR_VERSION}.tar.gz && \
        tar xzf ${PWD}/v${PSR_VERSION}.tar.gz && \
        # Download Phalcon
        curl -LO https://github.com/phalcon/cphalcon/archive/v${PHALCON_VERSION}.tar.gz && \
        tar xzf ${PWD}/v${PHALCON_VERSION}.tar.gz && \
        docker-php-ext-install -j $(getconf _NPROCESSORS_ONLN) \
            ${PWD}/php-psr-${PSR_VERSION} \
            ${PWD}/cphalcon-${PHALCON_VERSION}/build/${PHALCON_EXT_PATH} \
        && \
        # Remove all temp files
        rm -r \
            ${PWD}/v${PSR_VERSION}.tar.gz \
            ${PWD}/php-psr-${PSR_VERSION} \
            ${PWD}/v${PHALCON_VERSION}.tar.gz \
            ${PWD}/cphalcon-${PHALCON_VERSION} \
        && \
        php -m

#COPY docker-phalcon-* /usr/local/bin/

RUN apk add nginx npm
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php7/php-fpm.d/www.conf
COPY config/php.ini /etc/php7/conf.d/zzz_custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf


# Setup document root
RUN mkdir -p /var/www

# Make the document root a volume
VOLUME /var/www
#echo " > /usr/local/etc/php/conf.d/phalcon.ini
# Switch to use a non-root user from here on

# Add application
WORKDIR /var/www
COPY  src/ /var/www/

# Expose the port nginx is reachable on
EXPOSE 8080 9000

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Configure a healthcheck to validate that everything is up&running
#HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping
