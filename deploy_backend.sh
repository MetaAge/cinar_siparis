#!/bin/bash
set -e

SERVER="root@68.183.221.124"
TARGET="/var/www/cinar_siparis/backend"

echo "🚀 Server'a yükleniyor (storage KORUNUYOR)..."

rsync -avz --delete \
  --exclude '.env' \
  --exclude 'vendor/' \
  --exclude 'storage/' \
  --exclude 'public/storage/' \
  --exclude '.git/' \
  --exclude 'node_modules/' \
  . $SERVER:$TARGET/

echo "♻️ Laravel update ediliyor..."
ssh $SERVER << EOF
cd $TARGET
php artisan down || true

composer install --no-dev --optimize-autoloader

php artisan migrate --force
php artisan config:clear
php artisan route:clear
php artisan view:clear
php artisan storage:link
php artisan optimize
php artisan queue:restart

php artisan up
EOF

echo "✅ Backend deploy TAMAMLANDI"