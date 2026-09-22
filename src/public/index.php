<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

echo json_encode([
    'status' => 'ok',
    'php_version' => PHP_VERSION,
    'environment' => getenv('APP_ENV') ?: 'unknown',
    'extensions' => [
        'pdo_mysql' => extension_loaded('pdo_mysql'),
        'redis' => extension_loaded('redis'),
        'opcache' => extension_loaded('Zend OPcache'),
    ],
], JSON_THROW_ON_ERROR | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);

