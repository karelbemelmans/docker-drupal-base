# from https://www.drupal.org/requirements/php#drupalversions
FROM php:7.0-apache

# install the PHP extensions we need
RUN set -x && DEBIAN_FRONTEND=noninteractive && apt-get update \
  && apt-get install -y --no-install-recommends \
    libpng12-dev \
    libjpeg-dev \
    libpq-dev \
    mysql-client \
    unzip \
  && docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
  && docker-php-ext-install gd mbstring pdo pdo_mysql pdo_pgsql zip \
  && pecl install redis \
  && docker-php-ext-enable redis \
  && rm -rf /var/lib/apt/lists/*

# memcached php7 extension needs some special procedure
RUN set -x && DEBIAN_FRONTEND=noninteractive && apt-get update \
  && apt-get install -y --no-install-recommends \
    git \
    libmemcached-dev \
    libmemcached11 \
    build-essential \
  && cd /tmp \
  && git clone --branch php7 https://github.com/php-memcached-dev/php-memcached \
  && cd php-memcached && phpize && ./configure && make && make install \
  && docker-php-ext-enable memcached \
  && apt-get remove --purge -y build-essential git \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/php-memcached

# Enable apache rewrite module
RUN a2enmod rewrite

# Use our own apache2.conf that has been altered for reverse proxy log support
COPY config/apache2.conf /etc/apache2/apache2.conf

# Install Drupal core. This ARG's can be overriden during `docker build`
ARG DRUPAL_VERSION=7.54
ARG DRUPAL_SHA256=d74192aca31b56a95bd2b51f205e45293513466eaf902d056e6317dbcffe715b
RUN curl -fSL "https://ftp.drupal.org/files/projects/drupal-${DRUPAL_VERSION}.tar.gz" -o drupal.tar.gz \
  && echo "${DRUPAL_SHA256}  drupal.tar.gz" | sha256sum -c - \
  && tar -xz --strip-components=1 -f drupal.tar.gz \
  && rm drupal.tar.gz \
  && chown -R www-data:www-data sites

# CKEditor
ARG CKEDITOR_VERSION=4.5.10
RUN curl -fSL https://github.com/ckeditor/ckeditor-releases/archive/full/${CKEDITOR_VERSION}.zip \
      -o /tmp/ckeditor.zip \
      && unzip /tmp/ckeditor.zip -d sites/all/libraries/ \
      && mv sites/all/libraries/ckeditor-releases-full-${CKEDITOR_VERSION} sites/all/libraries/ckeditor \
      && rm -f /tmp/ckeditor.zip

# Install drush
ARG DRUSH_VERSION=8.1.10
RUN curl -fSL https://github.com/drush-ops/drush/releases/download/${DRUSH_VERSION}/drush.phar > /usr/local/bin/drush \
  && chmod +x /usr/local/bin/drush \
  && drush --version

# Create the sites/default/files folder so Drupal can write caches to it
RUN mkdir -p sites/default/files && chown www-data:www-data sites/default/files

# Change some PHP defaults.
RUN { \
    echo 'date.timezone = Europe/Stockholm'; \
  } > /usr/local/etc/php/conf.d/drupal-base.ini

# Remove some files from the Drupal base install.
RUN rm -f CHANGELOG.txt COPYRIGHT.txt INSTALL.mysql.txt INSTALL.pgsql.txt \
       INSTALL.sqlite.txt INSTALL.txt LICENSE.txt MAINTAINERS.txt \
       README.txt UPGRADE.txt

# Create an empty favicon.ico so it stops polluting our error logs.
# You might want to add more files here.
RUN touch favicon.ico

# Copy our local settings.php file into the container.
# This file uses a lot of environment variables to connect to services (db, cache)
COPY config/settings.php sites/default/settings.php

# Add Drupal modules, used for development purpose
RUN mkdir sites/all/modules/development \
  && drush dl coder devel schema --destination=sites/all/modules/development

# Add Drupal modules, generic contrib
RUN mkdir sites/all/modules/contrib \
  && drush dl context ctools date ds entity features google_analytics \
              libraries redis pathauto strongarm token transliteration \
              variable views views_bulk_operations wysiwyg-7.x-2.x-dev \
              xmlsitemap content_menu menu_block menu_position cdn smtp \
              seckit webform memcache-7.x-1.6-rc3

# Multilingual
RUN drush dl entity_translation i18n i18nviews l10n_update title

# Media
RUN drush dl media-2.x-dev file_entity-2.x-dev multiform \
             media_youtube-2.x-dev media_vimeo-2.x-dev \
             media_browser_plus-3.x-dev

# Custom modules for running Drupal 7 on AWS
RUN drush dl log_stdout

# Add Drupal themes
RUN mkdir sites/all/themes/contrib && drush dl mothership

# Finally set the workdir to the Drupal base folder
WORKDIR /var/www/html
