<?php
/**
 * Jewel Match — 아케이드 랭킹 API (단일 파일).
 *
 * GET  ?action=list          → 상위 30명 반환
 * GET  ?action=top1          → 1위만 반환 (HUD 표시용)
 * POST ?action=submit        → 점수 등록, 순위 응답
 *   body: {"name":"...", "score":12345}
 *
 * 데이터: 같은 디렉터리의 ranking_data.json (자동 생성).
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

define('DATA_FILE', __DIR__ . '/ranking_data.json');
define('MAX_ENTRIES', 30);

function loadData(): array {
    if (!file_exists(DATA_FILE)) return [];
    $raw = file_get_contents(DATA_FILE);
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}

function saveData(array $data): void {
    file_put_contents(
        DATA_FILE,
        json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT),
        LOCK_EX
    );
}

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'list':
        $data = loadData();
        echo json_encode(['ok' => true, 'ranking' => $data]);
        break;

    case 'top1':
        $data = loadData();
        if (empty($data)) {
            echo json_encode(['ok' => true, 'top1' => null]);
        } else {
            echo json_encode(['ok' => true, 'top1' => $data[0]]);
        }
        break;

    case 'submit':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            http_response_code(405);
            echo json_encode(['ok' => false, 'error' => 'POST required']);
            break;
        }
        $body = json_decode(file_get_contents('php://input'), true);
        $name  = trim($body['name'] ?? '');
        $score = intval($body['score'] ?? 0);
        if ($name === '' || $score <= 0) {
            http_response_code(400);
            echo json_encode(['ok' => false, 'error' => 'name and score required']);
            break;
        }
        $name = mb_substr($name, 0, 20);

        $data = loadData();
        $minScore = count($data) >= MAX_ENTRIES
            ? $data[count($data) - 1]['score']
            : 0;

        if (count($data) >= MAX_ENTRIES && $score <= $minScore) {
            echo json_encode([
                'ok'   => true,
                'ranked' => false,
                'message' => 'Not in top ' . MAX_ENTRIES,
            ]);
            break;
        }

        $entry = [
            'name'  => $name,
            'score' => $score,
            'ts'    => time(),
        ];
        $data[] = $entry;
        usort($data, fn($a, $b) => $b['score'] - $a['score']);
        $data = array_slice($data, 0, MAX_ENTRIES);
        $data = array_values($data);
        saveData($data);

        $rank = 0;
        foreach ($data as $i => $e) {
            if ($e['name'] === $name && $e['score'] === $score && $e['ts'] === $entry['ts']) {
                $rank = $i + 1;
                break;
            }
        }

        echo json_encode([
            'ok'     => true,
            'ranked' => true,
            'rank'   => $rank,
            'score'  => $score,
            'total'  => count($data),
        ]);
        break;

    default:
        http_response_code(400);
        echo json_encode(['ok' => false, 'error' => 'unknown action']);
}
