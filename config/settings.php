<?php

////////////////////////////////////////////////////////////////////////////////
// Database
$databases['default']['default'] = array(
  'driver'    => 'mysql', // since everyone uses MySQL we can hardcode this
  'database'  => $_ENV['DRUPAL_DB_NAME'],
  'username'  => $_ENV['DRUPAL_DB_USER'],
  'password'  => $_ENV['DRUPAL_DB_PASS'],
  'host'      => $_ENV['DRUPAL_DB_HOST'],
  'prefix'    => !empty($_ENV['DRUPAL_DB_PREFIX']) ? $_ENV['DRUPAL_DB_PREFIX'] : '',
  'charset'   => 'utf8mb4',
  'collation' => 'utf8mb4_general_ci',
);

////////////////////////////////////////////////////////////////////////////////
// Redis configuration
if (isset($_ENV['DRUPAL_REDIS_HOST']) && !empty($_ENV['DRUPAL_REDIS_HOST']) &&
  isset($_ENV['DRUPAL_REDIS_PORT']) && !empty($_ENV['DRUPAL_REDIS_PORT'])) {

  $conf['redis_client_interface'] = 'PhpRedis'; // Can be "Predis".
  $conf['redis_client_host']      = $_ENV['DRUPAL_REDIS_HOST'];  // Your Redis instance hostname.
  $conf['redis_client_port']      = $_ENV['DRUPAL_REDIS_PORT'];  // Your Redis instance hostname.
  $conf['lock_inc']               = 'sites/all/modules/contrib/redis/redis.lock.inc';
  $conf['path_inc']               = 'sites/all/modules/contrib/redis/redis.path.inc';
  $conf['cache_backends'][]       = 'sites/all/modules/contrib/redis/redis.autoload.inc';
  $conf['cache_default_class']    = 'Redis_Cache';
}

////////////////////////////////////////////////////////////////////////////////
// memcache configuration
else if (isset($_ENV['DRUPAL_MEMCACHE_HOST']) && !empty($_ENV['DRUPAL_MEMCACHE_HOST']) &&
  isset($_ENV['DRUPAL_MEMCACHE_PORT']) && !empty($_ENV['DRUPAL_MEMCACHE_PORT'])) {

  $conf['cache_backends'] = array('sites/all/modules/contrib/memcache/memcache.inc');
  $conf['cache_default_class'] = 'MemCacheDrupal';
  $conf['page_cache_without_database'] = TRUE;
  $conf['page_cache_invoke_hooks'] = FALSE;

  // The 'cache_form' bin must be assigned to non-volatile storage.
  $conf['cache_class_cache_form'] = 'DrupalDatabaseCache';

  // Memcache server to connect to, we just one for all caches
  $conf['memcache_servers'] = array($_ENV['DRUPAL_MEMCACHE_HOST'] . ':' . $_ENV['DRUPAL_MEMCACHE_PORT'] => 'default');
}

// Enforce SSL if the HTTP_X_FORWARDED_PROTO tell us to.
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https') {
  $base_url = 'https://'.$_SERVER['SERVER_NAME'];
}

// Needed when we run Drupal inside Docker
$conf['drupal_http_request_fails'] = FALSE;

// Never run cron from the website
$conf['cron_safe_threshold'] = 0;

// Is there an extra.settings.php file to include?
$settings = DRUPAL_ROOT . '/sites/default/extra.settings.php';
if (file_exists($settings)) {
 require_once($settings);
}
