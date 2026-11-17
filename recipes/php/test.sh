#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'kill "${fpm_pid:-}" "${serve_pid:-}" 2>/dev/null || true; rm -rf "$work"' EXIT

echo "== extensions"
# shellcheck disable=SC2046
php "$here/test/extensions.php" $("$ROOT/bin/recipe" php '.spc.extensions[]')

echo "== HTTPS with the system's certificates"
php -r 'echo strlen(file_get_contents("https://www.php.net/releases/index.php?json")) > 0 ? "ok\n" : exit(1);'

echo "== php-fpm"
root_user="" root_flag=()
if [ "$(id -u)" = 0 ]; then root_user=$'user = root\ngroup = root'; root_flag=(-R); fi
cat > "$work/fpm.conf" <<CONF
[global]
error_log = $work/fpm.log
daemonize = no
[www]
listen = 127.0.0.1:9123
pm = static
pm.max_children = 1
$root_user
CONF
php-fpm ${root_flag[@]+"${root_flag[@]}"} -t -y "$work/fpm.conf"
php-fpm ${root_flag[@]+"${root_flag[@]}"} -y "$work/fpm.conf" &
fpm_pid=$!
for _ in $(seq 1 50); do (exec 3<>/dev/tcp/127.0.0.1/9123) 2>/dev/null && break; sleep 0.1; done
(exec 3<>/dev/tcp/127.0.0.1/9123) 2>/dev/null || { cat "$work/fpm.log"; echo "php-fpm didn't listen" >&2; exit 1; }
kill "$fpm_pid"; wait "$fpm_pid" 2>/dev/null || true
echo ok

echo "== Laravel"
export COMPOSER_ALLOW_SUPERUSER=1
cd "$work"
"$ROOT/bin/fetch" php .composer "$work/composer.phar"
php "$work/composer.phar" create-project laravel/laravel app --no-interaction --no-progress --quiet
cd app
php artisan migrate --force --no-interaction
php artisan serve --port=8123 >"$work/serve.log" 2>&1 &
serve_pid=$!
for _ in $(seq 1 100); do curl -fsS -o /dev/null http://127.0.0.1:8123 2>/dev/null && break; sleep 0.2; done
page="$(curl -fsS http://127.0.0.1:8123)" || { cat "$work/serve.log"; echo "Laravel didn't answer" >&2; exit 1; }
grep -q Laravel <<<"$page" || { echo "$page" | head -20; echo "Laravel's page isn't Laravel's" >&2; exit 1; }
echo ok
