<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Deploy-Token');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'result' => 'Error',
        'errorMsg' => 'POST 메서드만 허용됩니다.',
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

function json_ok($payload) {
    echo json_encode(array_merge(['result' => 'OK'], $payload), JSON_UNESCAPED_UNICODE);
    exit;
}

function json_error($message, $status_code = 400) {
    http_response_code($status_code);
    echo json_encode([
        'result' => 'Error',
        'errorMsg' => $message,
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

function load_env_file($path) {
    if (!is_file($path)) {
        throw new Exception("서버 env 파일이 없습니다: {$path}");
    }

    $values = [];
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        $line = trim($line);
        if ($line === '' || strpos($line, '#') === 0) {
            continue;
        }

        $separator_pos = strpos($line, '=');
        if ($separator_pos === false) {
            continue;
        }

        $key = trim(substr($line, 0, $separator_pos));
        $value = trim(substr($line, $separator_pos + 1));
        $value = trim($value, "\"'");

        if ($key !== '') {
            $values[$key] = $value;
        }
    }

    return $values;
}

function get_request_header_value($name) {
    $server_key = 'HTTP_' . strtoupper(str_replace('-', '_', $name));
    if (isset($_SERVER[$server_key])) {
        return trim((string)$_SERVER[$server_key]);
    }

    if (function_exists('getallheaders')) {
        foreach (getallheaders() as $header_name => $header_value) {
            if (strcasecmp($header_name, $name) === 0) {
                return trim((string)$header_value);
            }
        }
    }

    return '';
}

function require_uploaded_zip() {
    if (!isset($_FILES['file']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK) {
        $error_msg = 'zip 파일 업로드 실패';
        if (isset($_FILES['file']['error'])) {
            switch ($_FILES['file']['error']) {
                case UPLOAD_ERR_INI_SIZE:
                case UPLOAD_ERR_FORM_SIZE:
                    $error_msg = '업로드 파일 크기가 PHP 설정 한도를 초과했습니다.';
                    break;
                case UPLOAD_ERR_PARTIAL:
                    $error_msg = '파일이 부분적으로만 업로드되었습니다.';
                    break;
                case UPLOAD_ERR_NO_FILE:
                    $error_msg = '파일이 업로드되지 않았습니다.';
                    break;
                case UPLOAD_ERR_NO_TMP_DIR:
                    $error_msg = '임시 폴더가 없습니다.';
                    break;
                case UPLOAD_ERR_CANT_WRITE:
                    $error_msg = '파일 쓰기 실패.';
                    break;
                case UPLOAD_ERR_EXTENSION:
                    $error_msg = '파일 업로드가 확장에 의해 중지되었습니다.';
                    break;
            }
        }
        throw new Exception($error_msg);
    }

    $uploaded_file = $_FILES['file'];
    $extension = strtolower(pathinfo($uploaded_file['name'], PATHINFO_EXTENSION));
    if ($extension !== 'zip') {
        throw new Exception('zip 파일만 업로드할 수 있습니다.');
    }

    return $uploaded_file;
}

function remove_path_recursive($path) {
    if (!file_exists($path)) {
        return;
    }

    if (is_file($path) || is_link($path)) {
        if (!unlink($path)) {
            throw new Exception("파일을 삭제할 수 없습니다: {$path}");
        }
        return;
    }

    $items = scandir($path);
    if ($items === false) {
        throw new Exception("디렉토리를 읽을 수 없습니다: {$path}");
    }

    foreach ($items as $item) {
        if ($item === '.' || $item === '..') {
            continue;
        }
        remove_path_recursive($path . DIRECTORY_SEPARATOR . $item);
    }

    if (!rmdir($path)) {
        throw new Exception("디렉토리를 삭제할 수 없습니다: {$path}");
    }
}

function validate_zip_entries($zip, $required_prefix) {
    for ($i = 0; $i < $zip->numFiles; $i++) {
        $name = $zip->getNameIndex($i);
        if ($name === false || $name === '') {
            throw new Exception('zip 내부 파일명을 읽을 수 없습니다.');
        }

        $normalized = str_replace('\\', '/', $name);
        if (
            strpos($normalized, "\0") !== false ||
            strpos($normalized, '../') !== false ||
            preg_match('#(^|/)\.\.($|/)#', $normalized) ||
            preg_match('#^/#', $normalized) ||
            preg_match('#^[a-zA-Z]:/#', $normalized)
        ) {
            throw new Exception("zip 내부에 허용되지 않는 경로가 있습니다: {$name}");
        }

        if ($normalized !== $required_prefix && strpos($normalized, $required_prefix . '/') !== 0) {
            throw new Exception("zip 내부 파일은 {$required_prefix}/ 폴더 아래에 있어야 합니다: {$name}");
        }
    }
}

$uploaded_zip_path = null;

try {
    $web_root = '/share/Web';
    $env_path = $web_root . '/.match_deploy.env';
    $target_dir = $web_root . '/match';
    $uploaded_zip_path = $web_root . '/match.zip';
    $public_url = 'https://cheng80.myqnapcloud.com/match/';

    if (!class_exists('ZipArchive')) {
        throw new Exception('PHP ZipArchive 확장이 필요합니다.');
    }

    if (!is_dir($web_root) || !is_writable($web_root)) {
        throw new Exception("웹 루트에 쓰기 권한이 없습니다: {$web_root}");
    }

    $env = load_env_file($env_path);
    $expected_token = isset($env['MATCH_DEPLOY_TOKEN']) ? trim($env['MATCH_DEPLOY_TOKEN']) : '';
    if ($expected_token === '') {
        throw new Exception('서버 env 파일에 MATCH_DEPLOY_TOKEN 값이 없습니다.');
    }

    $provided_token = get_request_header_value('X-Deploy-Token');
    if ($provided_token === '' && isset($_POST['deploy_token'])) {
        $provided_token = trim((string)$_POST['deploy_token']);
    }

    if ($provided_token === '' || !hash_equals($expected_token, $provided_token)) {
        json_error('배포 토큰이 올바르지 않습니다.', 401);
    }

    $uploaded_file = require_uploaded_zip();

    if (file_exists($uploaded_zip_path) && !unlink($uploaded_zip_path)) {
        throw new Exception("기존 zip 파일을 삭제할 수 없습니다: {$uploaded_zip_path}");
    }

    if (!move_uploaded_file($uploaded_file['tmp_name'], $uploaded_zip_path)) {
        throw new Exception("zip 파일 저장 실패: {$uploaded_zip_path}");
    }
    chmod($uploaded_zip_path, 0644);

    $zip = new ZipArchive();
    $open_result = $zip->open($uploaded_zip_path);
    if ($open_result !== true) {
        throw new Exception("zip 파일을 열 수 없습니다. ZipArchive code: {$open_result}");
    }

    validate_zip_entries($zip, 'match');

    remove_path_recursive($target_dir);

    if (!$zip->extractTo($web_root)) {
        $zip->close();
        throw new Exception("zip 압축 해제 실패: {$web_root}");
    }
    $zip->close();

    if (!is_file($target_dir . '/index.html')) {
        throw new Exception('압축 해제 후 match/index.html을 찾을 수 없습니다.');
    }

    if (file_exists($uploaded_zip_path) && !unlink($uploaded_zip_path)) {
        throw new Exception("배포 후 zip 파일을 삭제할 수 없습니다: {$uploaded_zip_path}");
    }
    $uploaded_zip_path = null;

    json_ok([
        'action' => 'deploy',
        'deploy_dir' => $target_dir,
        'public_url' => $public_url,
        'message' => 'match 웹 빌드 배포가 완료되었습니다.',
    ]);
} catch (Exception $e) {
    if ($uploaded_zip_path !== null && file_exists($uploaded_zip_path)) {
        @unlink($uploaded_zip_path);
    }
    json_error($e->getMessage(), 500);
}
