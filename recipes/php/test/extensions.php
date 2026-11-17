<?php

$names = ['opcache' => 'Zend OPcache'];
$missing = [];
foreach (array_slice($argv, 1) as $ext) {
    if (!extension_loaded($names[$ext] ?? $ext)) {
        $missing[] = $ext;
    }
}
if ($missing) {
    fwrite(STDERR, 'missing extensions: ' . implode(', ', $missing) . "\n");
    exit(1);
}

$check = function (string $what, bool $ok) {
    if (!$ok) {
        fwrite(STDERR, "failed: $what\n");
        exit(1);
    }
};

$gd = gd_info();
foreach (['JPEG Support', 'PNG Support', 'WebP Support', 'AVIF Support', 'FreeType Support'] as $feature) {
    $check("gd $feature", !empty($gd[$feature]));
}
$image = imagecreatetruecolor(8, 8);
ob_start();
imagewebp($image);
$check('gd writes WebP', strlen(ob_get_clean()) > 0);

$check('imagick reads its formats', in_array('PNG', Imagick::queryFormats('PNG'), true));
$check('intl formats', (new NumberFormatter('de_DE', NumberFormatter::DECIMAL))->format(1234.5) === '1.234,5');
$check('mbstring', mb_strtoupper('straße') === 'STRASSE');
$check('sodium', strlen(sodium_crypto_secretbox_keygen()) === SODIUM_CRYPTO_SECRETBOX_KEYBYTES);
$check('bcmath', bcadd('0.1', '0.2', 1) === '0.3');
$check('igbinary', igbinary_unserialize(igbinary_serialize(['a' => 1])) === ['a' => 1]);
$check('msgpack', msgpack_unpack(msgpack_pack([1, 2])) === [1, 2]);

$db = new PDO('sqlite::memory:');
$db->exec('create table t (v text)');
$db->exec("insert into t values ('ok')");
$check('pdo_sqlite', $db->query('select v from t')->fetchColumn() === 'ok');

$zip = new ZipArchive();
$file = tempnam(sys_get_temp_dir(), 'zip');
$check('zip writes', $zip->open($file, ZipArchive::OVERWRITE) === true && $zip->addFromString('a.txt', 'a') && $zip->close());
unlink($file);

$check('dom', (new DOMDocument())->loadXML('<a><b/></a>'));
$check('opcache is on', ini_get('opcache.enable') === '1');

echo count($argv) - 1 . " extensions loaded and working\n";
