FROM composer:latest AS composer
FROM php:8.1.2-fpm-alpine3.15
LABEL Maintainer="Marcelo Motta <marcelo.motta@mxserv.com.br>"

COPY --from=composer /usr/bin/composer /usr/bin/composer

# Envs
ENV LANG C.UTF-8
ENV APP_HOME /var/www/html

# Setup user
ARG UNAME=app_user
ARG UID=1001
ARG GID=1001
RUN addgroup -g $GID ${UNAME}
RUN adduser -D -H -u $UID -G ${UNAME} -s /bin/sh ${UNAME}

# Add application
WORKDIR $APP_HOME

# Install packages
RUN apk --no-cache add php8-json php8-openssl php8-curl \
    php8-zlib php8-xml php8-phar php8-intl php8-dom php8-xmlreader php8-ctype php8-session \
    php8-mbstring php8-gd php8-simplexml php8-tokenizer php8-fileinfo php8-xmlwriter php8-redis php8-pecl-imagick php8-iconv \
    file imagemagick ghostscript nginx curl redis supervisor postgresql-dev

RUN docker-php-ext-install bcmath pdo pdo_pgsql


# Configure nginx
COPY environment/nginx.conf /etc/nginx/http.d/default.conf

# Configure PHP-FPM
COPY environment/fpm-pool.conf /etc/php8/php-fpm.d/www.conf
COPY environment/php.ini /etc/php8/conf.d/custom.ini
COPY environment/php-fpm.conf /etc/php8/php-fpm.conf
RUN ln -s /usr/bin/php8 /usr/bin/php

# Configure supervisord
COPY environment/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R nginx.nginx /run && \
  chown -R nginx:nginx /var/lib/nginx && \
  chown -R nginx:nginx /var/log/nginx

# Setup document root
RUN mkdir -p /var/www/html

# Copy all files
COPY --chown=$UNAME . $APP_HOME/

# Install composer dependencies
COPY .env.production .env
RUN composer install --optimize-autoloader --no-dev --no-interaction --prefer-dist
RUN php artisan optimize

# Expose the port nginx is reachable on
EXPOSE 80

# Configure a healthcheck to validate that everything is up&running
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1:80

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
