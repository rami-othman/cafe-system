FROM php:8.4-cli AS base

RUN apt-get update \
    && apt-get install -y --no-install-recommends libonig-dev libpq-dev unzip \
    && docker-php-ext-install mbstring pdo_pgsql \
    && rm -rf /var/lib/apt/lists/*

RUN { \
        echo 'opcache.enable=1'; \
        echo 'opcache.enable_cli=1'; \
        echo 'opcache.memory_consumption=192'; \
        echo 'opcache.interned_strings_buffer=16'; \
        echo 'opcache.max_accelerated_files=20000'; \
        echo 'opcache.validate_timestamps=0'; \
        echo 'realpath_cache_size=16M'; \
        echo 'realpath_cache_ttl=600'; \
    } > /usr/local/etc/php/conf.d/zz-performance.ini

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# The Compose service selects this target. It intentionally retains the old
# bind-mount based local development workflow.
FROM base AS development

CMD ["tail", "-f", "/dev/null"]

FROM composer:2 AS vendor

WORKDIR /app

COPY backend/composer.json backend/composer.lock ./

RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader --no-scripts

# This is the self-contained Render/staging image. Build it explicitly with
# `docker build --target cloud -t cafe-system-618-backend:phase-1a .`.
FROM base AS cloud

COPY backend/ /var/www/html/
COPY --from=vendor /app/vendor/ /var/www/html/vendor/

RUN chmod +x /var/www/html/docker/cloud-entrypoint.sh \
    && rm -f bootstrap/cache/packages.php bootstrap/cache/services.php \
    && php artisan package:discover --ansi \
    && mkdir -p storage/app/private storage/app/public storage/framework/cache/data storage/framework/sessions storage/framework/testing storage/framework/views storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && find storage bootstrap/cache -type d -exec chmod 775 {} \; \
    && find storage bootstrap/cache -type f -exec chmod 664 {} \;

USER www-data

# Ephemeral, file-backed framework state is safe for this single staging
# container and avoids requiring cache/session tables just to boot.
ENV CACHE_STORE=file \
    SESSION_DRIVER=file \
    QUEUE_CONNECTION=sync \
    LOG_CHANNEL=stderr

ENTRYPOINT ["/var/www/html/docker/cloud-entrypoint.sh"]
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--no-reload"]
