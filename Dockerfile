# from https://www.drupal.org/requirements/php#drupalversions
FROM php:7.0-apache

# Install the deb packages and PHP extensions we need
#
# Notes:
# - We need to install the couchbase release package before we can apt-get install the real package
# - memcached needs manual git checkout
RUN set -x && DEBIAN_FRONTEND=noninteractive \
  && apt-get update && apt-get install -y --no-install-recommends lsb-release wget \
  && wget http://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-2-amd64.deb \
  && dpkg -i couchbase-release-1.0-2-amd64.deb \
  && apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    libcouchbase-dev \
    libcouchbase2-bin \
    libjpeg-dev \
    libldap2-dev \
    libmemcached-dev \
    libmemcached11 \
    libpng12-dev \
    libpq-dev \
    mysql-client \
    unzip \
  && docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
  && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
  && docker-php-ext-install gd ldap mbstring pdo pdo_mysql pdo_pgsql sockets zip \
  && pecl install igbinary redis couchbase \
  && cd /tmp && git clone --branch php7 https://github.com/php-memcached-dev/php-memcached \
  && cd php-memcached && phpize && ./configure && make && make install \
  && docker-php-ext-enable igbinary redis couchbase memcached \
  && apt-get remove --purge -y build-essential git \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/php-memcached

# Enable apache rewrite module
RUN a2enmod rewrite

# Use our own apache2.conf that has been altered for reverse proxy log support
COPY config/apache2.conf /etc/apache2/apache2.conf

# Install Drupal core. This ARG's can be overriden during `docker build`
ARG DRUPAL_VERSION=7.56
ARG DRUPAL_MD5=5d198f40f0f1cbf9cdf1bf3de842e534
RUN curl -fSL "https://ftp.drupal.org/files/projects/drupal-${DRUPAL_VERSION}.tar.gz" -o drupal.tar.gz \
  && echo "${DRUPAL_MD5}  drupal.tar.gz" | md5sum -c - \
  && tar -xz --strip-components=1 -f drupal.tar.gz \
  && rm drupal.tar.gz

# CKEditor
ARG CKEDITOR_VERSION=4.5.10
RUN curl -fSL https://github.com/ckeditor/ckeditor-releases/archive/full/${CKEDITOR_VERSION}.zip \
      -o /tmp/ckeditor.zip \
      && unzip /tmp/ckeditor.zip -d sites/all/libraries/ \
      && mv sites/all/libraries/ckeditor-releases-full-${CKEDITOR_VERSION} sites/all/libraries/ckeditor \
      && rm -f /tmp/ckeditor.zip

# Colorbox plugin 1.x
RUN curl -fSL https://github.com/jackmoore/colorbox/archive/1.x.zip -o /tmp/colorbox.zip \
      && unzip /tmp/colorbox.zip -d sites/all/libraries \
      && mv sites/all/libraries/colorbox-1.x sites/all/libraries/colorbox \
      && rm -f /tmp/colorbox.zip

# Install drush
ARG DRUSH_VERSION=8.1.10
RUN curl -fSL https://github.com/drush-ops/drush/releases/download/${DRUSH_VERSION}/drush.phar > /usr/local/bin/drush \
  && chmod +x /usr/local/bin/drush \
  && drush --version

# Create the sites/default/files folder so Drupal can write caches to it
RUN mkdir -p sites/default/files && chown www-data:www-data sites/default/files

# Change some PHP defaults.
COPY config/php.ini /usr/local/etc/php/conf.d/drupal.ini

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

# Add Drupal contrib modules
RUN mkdir sites/all/modules/contrib \
  && drush dl \
    cdn \
    colorbox \
    content_menu \
    context \
    couchbasedrupal \
    ctools \
    date \
    ds \
    entity \
    entity_translation \
    facetapi \
    features \
    file_entity-2.x-dev \
    google_analytics \
    i18n \
    i18nviews \
    l10n_update \
    ldap \
    libraries \
    log_stdout \
    media-2.x-dev \
    memcache-7.x-1.6-rc3 \
    menu_block \
    menu_position \
    multiform \
    pathauto \
    redis \
    search_api \
    search_api_db \
    search_api_solr \
    seckit \
    smtp \
    strongarm \
    title \
    token \
    transliteration \
    variable \
    views \
    views_bulk_operations \
    webform \
    wysiwyg-7.x-2.x-dev \
    xmlsitemap

# Add Drupal themes
RUN mkdir sites/all/themes/contrib && drush dl mothership

# Finally set the workdir to the Drupal base folder
WORKDIR /var/www/html

COPY entrypoint.sh /
CMD ["/entrypoint.sh"]
