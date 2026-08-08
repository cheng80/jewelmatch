<?php
/**
 * Stone Match — 아케이드 랭킹 API (단일 파일).
 *
 * GET  ?action=list&mode=time|level   → 상위 30명 반환
 * GET  ?action=top1&mode=time|level   → 1위만 반환 (HUD 표시용)
 * POST ?action=submit&mode=time|level → 점수/레벨 등록, 순위 응답
 *   body: {"name":"...", "score":12345, "mode":"time"}
 *
 * 데이터: 같은 디렉터리의 ranking_data.json / ranking_level_data.json (자동 생성).
 * 동일 이름 여러 항목 허용(아케이드 방식). 최대 30건만 유지.
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

define('MAX_ENTRIES', 30);

function rankingMode(): string {
    $mode = $_GET['mode'] ?? '';
    return $mode === 'level' ? 'level' : 'time';
}

function dataFile(string $mode): string {
    return $mode === 'level'
        ? __DIR__ . '/ranking_level_data.json'
        : __DIR__ . '/ranking_data.json';
}

function lockFile(string $mode): string {
    return __DIR__ . '/ranking_' . $mode . '.lock';
}

function loadData(string $mode, &$failed): array {
    $failed = false;
    $file = dataFile($mode);
    if (!file_exists($file)) return [];

    $handle = @fopen($file, 'rb');
    if (!is_resource($handle)) {
        error_log('ranking load failed: fopen returned false');
        $failed = true;
        return [];
    }

    if (!@flock($handle, LOCK_SH)) {
        error_log('ranking load failed: flock returned false');
        @fclose($handle);
        $failed = true;
        return [];
    }

    try {
        $raw = @stream_get_contents($handle);
    } finally {
        if (!@flock($handle, LOCK_UN)) {
            error_log('ranking load unlock failed');
        }
        if (!@fclose($handle)) {
            error_log('ranking load close failed');
        }
    }

    if (!is_string($raw)) {
        error_log('ranking load failed: stream_get_contents returned false');
        $failed = true;
        return [];
    }

    $data = json_decode($raw, true);
    if (json_last_error() !== JSON_ERROR_NONE || !is_array($data)) {
        error_log('ranking load failed: JSON decode error: ' . json_last_error_msg());
        $failed = true;
        return [];
    }

    return $data;
}

function saveData(string $mode, array $data): bool {
    $encoded = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    if (!is_string($encoded)) {
        error_log('ranking save failed: JSON encoding error: ' . json_last_error_msg());
        return false;
    }

    $tempFile = @tempnam(__DIR__, '.ranking_data.');
    if (!is_string($tempFile) || dirname($tempFile) !== __DIR__) {
        if (is_string($tempFile) && is_file($tempFile)) @unlink($tempFile);
        error_log('ranking save failed: temporary file creation failed');
        return false;
    }

    $written = @file_put_contents($tempFile, $encoded, LOCK_EX);
    if ($written !== strlen($encoded)) {
        error_log('ranking save failed: incomplete write');
        @unlink($tempFile);
        return false;
    }

    if (!@rename($tempFile, dataFile($mode))) {
        error_log('ranking save failed: rename failed');
        @unlink($tempFile);
        return false;
    }

    return true;
}

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'list':
        $mode = rankingMode();
        $loadFailed = false;
        $data = loadData($mode, $loadFailed);
        if ($loadFailed) {
            http_response_code(500);
            echo json_encode(['ok' => false, 'error' => 'ranking_load_failed']);
            break;
        }
        echo json_encode(['ok' => true, 'mode' => $mode, 'ranking' => $data]);
        break;

    case 'top1':
        $mode = rankingMode();
        $loadFailed = false;
        $data = loadData($mode, $loadFailed);
        if ($loadFailed) {
            http_response_code(500);
            echo json_encode(['ok' => false, 'error' => 'ranking_load_failed']);
            break;
        }
        if (empty($data)) {
            echo json_encode(['ok' => true, 'mode' => $mode, 'top1' => null]);
        } else {
            echo json_encode(['ok' => true, 'mode' => $mode, 'top1' => $data[0]]);
        }
        break;

    case 'submit':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            http_response_code(405);
            echo json_encode(['ok' => false, 'error' => 'POST required']);
            break;
        }
        $rawBody = file_get_contents('php://input');
        $body = json_decode($rawBody, true);
        if (!is_array($body)) {
            http_response_code(400);
            echo json_encode(['ok' => false, 'error' => 'invalid JSON']);
            break;
        }
        $mode = ($_GET['mode'] ?? ($body['mode'] ?? '')) === 'level' ? 'level' : 'time';
        $name  = trim($body['name'] ?? '');
        $score = intval($body['score'] ?? 0);
        if ($name === '' || $score <= 0) {
            http_response_code(400);
            echo json_encode(['ok' => false, 'error' => 'name and score required']);
            break;
        }
        $name = mb_substr($name, 0, 20);

        $lockHandle = @fopen(lockFile($mode), 'c');
        if (!is_resource($lockHandle)) {
            error_log('ranking lock failed: fopen returned false');
            http_response_code(500);
            echo json_encode(['ok' => false, 'error' => 'ranking_save_failed']);
            break;
        }

        if (!@flock($lockHandle, LOCK_EX)) {
            error_log('ranking lock failed: flock returned false');
            @fclose($lockHandle);
            http_response_code(500);
            echo json_encode(['ok' => false, 'error' => 'ranking_save_failed']);
            break;
        }

        $response = null;
        $status = 200;
        try {
            $loadFailed = false;
            $data = loadData($mode, $loadFailed);
            if ($loadFailed) {
                $response = ['ok' => false, 'error' => 'ranking_load_failed'];
                $status = 500;
            } else {
                $minScore = count($data) >= MAX_ENTRIES
                    ? $data[count($data) - 1]['score']
                    : 0;

                if (count($data) >= MAX_ENTRIES && $score <= $minScore) {
                    $response = [
                        'ok' => true,
                        'mode' => $mode,
                        'ranked' => false,
                        'message' => 'Not in top ' . MAX_ENTRIES,
                    ];
                } else {
                    $entry = [
                        'name' => $name,
                        'score' => $score,
                        'ts' => time(),
                    ];
                    $data[] = $entry;
                    usort($data, fn($a, $b) => $b['score'] - $a['score']);
                    $data = array_values(array_slice($data, 0, MAX_ENTRIES));

                    $rank = 0;
                    foreach ($data as $i => $candidate) {
                        if ($candidate['name'] === $entry['name']
                            && $candidate['score'] === $entry['score']
                            && $candidate['ts'] === $entry['ts']) {
                            $rank = $i + 1;
                            break;
                        }
                    }

                    if (!saveData($mode, $data)) {
                        $response = ['ok' => false, 'error' => 'ranking_save_failed'];
                        $status = 500;
                    } else {
                        $response = [
                            'ok' => true,
                            'mode' => $mode,
                            'ranked' => true,
                            'rank' => $rank,
                            'score' => $score,
                            'total' => count($data),
                        ];
                    }
                }
            }
        } finally {
            if (!@flock($lockHandle, LOCK_UN)) {
                error_log('ranking lock release failed');
            }
            if (!@fclose($lockHandle)) {
                error_log('ranking lock close failed');
            }
        }

        http_response_code($status);
        echo json_encode($response);
        break;

    default:
        http_response_code(400);
        echo json_encode(['ok' => false, 'error' => 'unknown action']);
}
