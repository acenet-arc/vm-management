FROM php:8.1-apache

ARG OMEKA_VERSION="4.0.4"

RUN apt-get update && apt-get install -y imagemagick unzip libzip-dev
RUN curl -fL -o /usr/src/omeka-s.zip https://github.com/omeka/omeka-s/releases/download/v${OMEKA_VERSION}/omeka-s-${OMEKA_VERSION}.zip
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride all/' /etc/apache2/apache2.conf

RUN set -ex; \
  docker-php-ext-install -j "$(nproc)" \
    pdo_mysql \
    zip \
  ;

RUN a2enmod rewrite

VOLUME /var/www/html

COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
