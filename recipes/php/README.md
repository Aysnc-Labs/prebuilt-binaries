# php

PHP CLI and FPM, built static with [static-php-cli](https://github.com/crazywhalecc/static-php-cli). On Linux the binaries link against musl, so they run on any distro, as root too.

The extensions are what the official WordPress image and Laravel Sail's 8.5 runtime install, plus Laravel's requirements. gd is built with AVIF, WebP, JPEG and FreeType. Left out:

- `imap`: removed from PHP in 8.4.
- `swoole`: only Octane uses it, and in static builds it conflicts with `pdo_pgsql` and `pdo_sqlite`.
- `xdebug` and `pcov`: static-php-cli can only build them as shared extensions, which a static binary can't load.

`--with-php` only takes a major.minor version, so `build.sh` passes the exact release to static-php-cli as php-src's URL.

The binaries read `php.ini` from `/usr/local/etc/php`. Set `PHPRC` to use another.
