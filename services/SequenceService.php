<?php
/**
 * Concurrency-Safe Sequence & Number Generator
 * Guarantees monotonic, race-condition-free Requisition & Sub-Requisition numbers
 */

require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../config/config.php';

class SequenceService {
    /**
     * Generate next Master Requisition number in format REQ-YYYYMMDD-XXX
     * Must be called inside an active database transaction.
     */
    public static function generateMasterRequisitionNo(PDO $db, string $date): string {
        $cleanDate = date('Y-m-d', strtotime($date));
        $dateFormatted = date('Ymd', strtotime($date));

        // Lock sequence row for this date
        $selectSql = "SELECT last_seq FROM daily_sequences WHERE seq_date = :seq_date FOR UPDATE";
        $stmt = $db->prepare($selectSql);
        $stmt->execute([':seq_date' => $cleanDate]);
        $row = $stmt->fetch();

        if ($row === false) {
            // First requisition for this date
            $nextSeq = 1;
            $insertSql = "INSERT INTO daily_sequences (seq_date, last_seq, updated_at) VALUES (:seq_date, 1, NOW())";
            $insStmt = $db->prepare($insertSql);
            $insStmt->execute([':seq_date' => $cleanDate]);
        } else {
            $nextSeq = ((int) $row['last_seq']) + 1;
            $updateSql = "UPDATE daily_sequences SET last_seq = :seq, updated_at = NOW() WHERE seq_date = :seq_date";
            $updStmt = $db->prepare($updateSql);
            $updStmt->execute([':seq' => $nextSeq, ':seq_date' => $cleanDate]);
        }

        // Format as 3-digit padded number: REQ-20260828-015
        $seqPadded = str_pad((string) $nextSeq, 3, '0', STR_PAD_LEFT);
        return "REQ-{$dateFormatted}-{$seqPadded}";
    }

    /**
     * Generate Sub Requisition number for a Master Requisition
     * Example: REQ-20260828-015/01 or REQ-20260828-015/02
     */
    public static function generateSubRequisitionNo(PDO $db, int $requisitionId, string $masterReqNo, int $locationId): string {
        $mode = Config::get('SUB_REQ_SUFFIX_MODE', 'SEQUENTIAL');

        if ($mode === 'LOCATION_CODE') {
            $locStmt = $db->prepare("SELECT code FROM locations WHERE id = :id");
            $locStmt->execute([':id' => $locationId]);
            $loc = $locStmt->fetch();
            $suffix = $loc ? preg_replace('/[^a-zA-Z0-9]/', '', $loc['code']) : '01';
            $candidate = "{$masterReqNo}/{$suffix}";

            $checkStmt = $db->prepare("SELECT id FROM requisition_subs WHERE sub_requisition_no = :no LIMIT 1 FOR UPDATE");
            $checkStmt->execute([':no' => $candidate]);
            if (!$checkStmt->fetch()) {
                return $candidate;
            }
        }

        // Sequential Mode: Query all existing sub numbers matching this master requisition prefix
        $stmt = $db->prepare("SELECT sub_requisition_no FROM requisition_subs WHERE sub_requisition_no LIKE :prefix FOR UPDATE");
        $stmt->execute([':prefix' => "{$masterReqNo}/%"]);
        $existing = $stmt->fetchAll(PDO::FETCH_COLUMN);

        $maxSuffix = 0;
        foreach ($existing as $no) {
            $parts = explode('/', $no);
            if (isset($parts[1]) && is_numeric($parts[1])) {
                $val = (int) $parts[1];
                if ($val > $maxSuffix) {
                    $maxSuffix = $val;
                }
            }
        }

        $nextIndex = max($maxSuffix + 1, 1);
        while (true) {
            $candidate = sprintf("%s/%02d", $masterReqNo, $nextIndex);
            $checkStmt = $db->prepare("SELECT id FROM requisition_subs WHERE sub_requisition_no = :no LIMIT 1 FOR UPDATE");
            $checkStmt->execute([':no' => $candidate]);
            if (!$checkStmt->fetch()) {
                return $candidate;
            }
            $nextIndex++;
        }
    }

    /**
     * Generate unique Tally Export Batch ID
     * Example: TALLY-20260828-001
     */
    public static function generateTallyBatchId(): string {
        $todayStr = date('Ymd');
        $sql = "SELECT COUNT(*) AS total FROM tally_export_batches WHERE DATE(created_at) = CURDATE()";
        $row = Database::queryOne($sql);
        $nextBatch = ((int) ($row['total'] ?? 0)) + 1;
        $padded = str_pad((string) $nextBatch, 3, '0', STR_PAD_LEFT);
        return "TALLY-{$todayStr}-{$padded}";
    }
}
