<?php

require_once __DIR__ . '/Http.php';

/**
 * File uploads for the exam module (question papers and student answer sheets).
 * Files are saved in public/uploads/exams/ with a random name; the real file type is
 * checked from the file's content (not the name the browser sent).
 */
class Upload
{
    /** allowed real MIME type => extension used for the saved file */
    public const ALLOWED = [
        'application/pdf' => 'pdf',
        'image/jpeg'      => 'jpg',
        'image/png'       => 'png',
        'image/webp'      => 'webp',
        'image/gif'       => 'gif',
        'image/heic'      => 'heic',
        'image/heif'      => 'heic',
    ];

    private static function dir(): string
    {
        $dir = __DIR__ . '/../public/uploads/exams';
        if (!is_dir($dir)) {
            if (!mkdir($dir, 0755, true) && !is_dir($dir)) {
                Http::fail(500, 'Could not create the uploads folder. Check folder permissions.');
            }
            // never let an uploaded file run as code
            file_put_contents(
                __DIR__ . '/../public/uploads/.htaccess',
                "# uploaded files are only ever downloaded, never executed\n"
                . "<FilesMatch \"\\.(php|phtml|phar|php[0-9])\$\">\n    Require all denied\n</FilesMatch>\n"
                . "Options -Indexes\n"
            );
        }
        return $dir;
    }

    /** Public URL of a saved file, e.g. http://localhost/App/backend/public/uploads/exams/q_ab12.pdf */
    public static function url(?string $name): ?string
    {
        if (!$name) return null;
        $https  = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
            || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');
        $uri    = parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH) ?: '';
        $pos    = strpos($uri, '/api/');
        $prefix = $pos !== false ? substr($uri, 0, $pos) : '';
        return ($https ? 'https' : 'http') . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost')
            . $prefix . '/uploads/exams/' . rawurlencode(basename($name));
    }

    /** Sends a clear error when the whole request was rejected by PHP's size limits. */
    public static function failIfRequestTooBig(): void
    {
        if (empty($_FILES) && empty($_POST) && (int) ($_SERVER['CONTENT_LENGTH'] ?? 0) > 0) {
            Http::fail(413, 'The upload is too big for the server. Increase post_max_size and upload_max_filesize in php.ini, or upload fewer/smaller pages.');
        }
    }

    /** Uploaded files for one form field ("files[]" or a single file), as a flat list. */
    public static function files(string $field): array
    {
        if (empty($_FILES[$field])) return [];
        $f = $_FILES[$field];
        $out = [];
        if (is_array($f['name'])) {
            foreach ($f['name'] as $i => $name) {
                $out[] = ['name' => $name, 'tmp_name' => $f['tmp_name'][$i], 'error' => $f['error'][$i], 'size' => $f['size'][$i]];
            }
        } else {
            $out[] = $f;
        }
        return array_values(array_filter($out, fn($x) => $x['error'] !== UPLOAD_ERR_NO_FILE));
    }

    /** Checks one uploaded file. Returns its extension, or sends a 400 error. */
    public static function check(array $f, int $maxBytes): string
    {
        $label = $f['name'] ?? 'file';
        if ($f['error'] === UPLOAD_ERR_INI_SIZE || $f['error'] === UPLOAD_ERR_FORM_SIZE) {
            Http::fail(413, "$label is larger than the server allows. Increase upload_max_filesize in php.ini.");
        }
        if ($f['error'] !== UPLOAD_ERR_OK) Http::fail(400, "$label could not be uploaded (error {$f['error']})");
        if ($f['size'] > $maxBytes) Http::fail(400, "$label is larger than " . (int) ($maxBytes / 1048576) . ' MB');
        if (!is_uploaded_file($f['tmp_name'])) Http::fail(400, "$label is not a valid upload");

        $mime = (new finfo(FILEINFO_MIME_TYPE))->file($f['tmp_name']);
        if (!isset(self::ALLOWED[$mime])) Http::fail(400, "$label: only PDF or image files (JPG, PNG, WEBP, HEIC) are allowed");
        return self::ALLOWED[$mime];
    }

    /** Moves a checked file into the uploads folder. Returns the stored file name. */
    public static function save(array $f, string $ext, string $prefix): string
    {
        $name = $prefix . '_' . bin2hex(random_bytes(16)) . '.' . $ext;
        if (!move_uploaded_file($f['tmp_name'], self::dir() . '/' . $name)) {
            Http::fail(500, 'Could not save the uploaded file. Check folder permissions.');
        }
        return $name;
    }

    public static function delete(?string $name): void
    {
        if (!$name) return;
        $path = self::dir() . '/' . basename($name);
        if (is_file($path)) @unlink($path);
    }
}