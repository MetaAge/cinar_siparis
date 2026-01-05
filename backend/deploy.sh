#!/bin/bash

echo "----------------------------------------"
echo "🚀 Cinar Siparis | Backend Deploy Started"
echo "----------------------------------------"

set -e   # herhangi bir hata olursa script DURUR

PROJECT_PATH="/var/www/cinar_siparis/backend"
PHP_BIN="/usr/bin/php"
COMPOSER_BIN="/usr/bin/composer"

cd $PROJECT_PATH

echo "📌 Current directory:"
pwd

echo "----------------------------------------"
echo "📥 Pulling latest code from Git..."
git pull origin main

echo "----------------------------------------"
echo "📦 Installing Composer dependencies..."
$COMPOSER_BIN install --no-dev --optimize-autoloader

echo "----------------------------------------"
echo "🗄 Running database migrations..."
$PHP_BIN artisan migrate --force

echo "----------------------------------------"
echo "🧹 Clearing caches..."
$PHP_BIN artisan optimize:clear

echo "----------------------------------------"
echo "⚡ Rebuilding caches..."
$PHP_BIN artisan config:cache
$PHP_BIN artisan route:cache
$PHP_BIN artisan view:cache

echo "----------------------------------------"
echo "♻️ Reloading PHP-FPM..."
systemctl reload php8.2-fpm

echo "----------------------------------------"
echo "✅ Deploy completed successfully!"
echo "----------------------------------------"
