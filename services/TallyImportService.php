<?php
/**
 * Tally Material Import & Incremental Diff Synchronization Service
 * Handles Excel parsing, delta analysis, auto-code generation, and atomic catalog sync.
 */

require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../core/XlsxReader.php';
require_once __DIR__ . '/../core/Logger.php';

class TallyImportService {

    /**
     * Parse Tally Stock Summary Excel File
     *
     * @param string $filePath Absolute path to uploaded .xlsx file
     * @return array<int, array<string, mixed>> Extracted raw Tally items
     */
    public static function parseTallyStockSummary(string $filePath): array {
        $rows = XlsxReader::read($filePath);

        // Find header row offset
        $dataStartRow = 1;
        $nameCol = 'A';
        $qtyCol = 'B';
        $unitCol = null;
        $rateCol = 'C';
        $valCol = 'D';

        foreach ($rows as $rowNum => $row) {
            foreach ($row as $col => $val) {
                $v = strtolower(trim((string)$val));
                if (in_array($v, ['particulars', 'item name', 'stock item', 'item'])) {
                    $nameCol = $col;
                    $dataStartRow = $rowNum + 1;
                }
                if (in_array($v, ['rate', 'unit rate', 'rate (rs.)', 'rate(rs)'])) {
                    $rateCol = $col;
                }
                if (in_array($v, ['quantity', 'closing balance', 'qty', 'stock qty', 'closing qty', 'closing balance qty'])) {
                    $qtyCol = $col;
                }
                if (in_array($v, ['unit', 'units', 'base units', 'uom', 'base unit', 'unit of measurement'])) {
                    $unitCol = $col;
                }
                if (in_array($v, ['value', 'amount', 'total value'])) {
                    $valCol = $col;
                }
            }
            if ($dataStartRow > 1 && $rowNum >= $dataStartRow) {
                // If next row contains subheaders like Quantity/Rate/Value, advance past it
                $firstCell = strtolower(trim((string)($row[$nameCol] ?? '')));
                if (empty($firstCell) || in_array($firstCell, ['quantity', 'rate', 'value', 'closing balance', 'opening balance', 'unit'])) {
                    $dataStartRow = $rowNum + 1;
                } else {
                    break;
                }
            }
        }

        // If no header found, default start row is 8 (standard Tally StkSum export)
        if ($dataStartRow === 1) {
            $dataStartRow = 8;
        }

        $extracted = [];
        foreach ($rows as $rowNum => $row) {
            if ($rowNum < $dataStartRow) continue;

            $itemName = trim((string)($row[$nameCol] ?? ''));
            if (empty($itemName)) continue;

            $lowerName = strtolower($itemName);
            // Skip summary rows & headers
            if (in_array($lowerName, ['grand total', 'total', 'particulars', 'closing balance', 'item name', 'quantity', 'rate', 'value', 'unit'])) {
                continue;
            }

            $qtyRaw = $row[$qtyCol] ?? 0;
            $rateRaw = $row[$rateCol] ?? 0;
            $valRaw = $row[$valCol] ?? 0;
            $unitRaw = !empty($unitCol) ? trim((string)($row[$unitCol] ?? '')) : '';

            // Clean quantity (handles numeric or "337 MTR")
            $qty = 0.0;
            if (is_numeric($qtyRaw)) {
                $qty = (float)$qtyRaw;
            } elseif (preg_match('/^([+-]?[0-9.]+)\s*([a-zA-Z\/]*)/', trim((string)$qtyRaw), $m)) {
                $qty = (float)$m[1];
                if (empty($unitRaw) && !empty($m[2])) {
                    $unitRaw = $m[2];
                }
            }

            // Clean rate (handles numeric or "54.66/MTR")
            $rate = 0.0;
            if (is_numeric($rateRaw)) {
                $rate = (float)$rateRaw;
            } elseif (preg_match('/^([+-]?[0-9.]+)/', trim((string)$rateRaw), $m)) {
                $rate = (float)$m[1];
            }
            if (empty($unitRaw) && preg_match('/\/([a-zA-Z]+)/', (string)$rateRaw, $m)) {
                $unitRaw = $m[1];
            }

            $value = is_numeric($valRaw) ? (float)$valRaw : 0.0;
            $cleanUnit = self::normalizeUnit($unitRaw, $itemName);

            $extracted[] = [
                'excel_row'    => $rowNum,
                'tally_name'   => $itemName,
                'unit'         => $cleanUnit,
                'closing_qty'  => $qty,
                'rate'         => $rate,
                'value'        => $value
            ];
        }

        return $extracted;
    }

    /**
     * Compare raw Tally items against existing Material Catalog and classify into Diff categories
     *
     * @param array $rawItems Output from parseTallyStockSummary
     * @return array Delta analysis report with statistics and staged items
     */
    public static function analyzeDelta(array $rawItems): array {
        // Fetch all existing materials
        $existingMaterials = Database::query("SELECT id, name, code, unit, default_rate, tally_item_name, category_id, status FROM materials");
        
        $nameMap = [];
        $tallyMap = [];
        $maxSequence = 0;

        foreach ($existingMaterials as $mat) {
            $nameKey = self::normalizeKey($mat['name']);
            $nameMap[$nameKey] = $mat;

            if (!empty($mat['tally_item_name'])) {
                $tallyKey = self::normalizeKey($mat['tally_item_name']);
                $tallyMap[$tallyKey] = $mat;
            }

            // Extract sequence number from MAT-XXXX
            if (preg_match('/MAT-0*([0-9]+)/i', $mat['code'], $matches)) {
                $seq = (int)$matches[1];
                if ($seq > $maxSequence) {
                    $maxSequence = $seq;
                }
            }
        }

        // Fetch active categories for mapping
        $categories = Database::query("SELECT id, name FROM material_categories WHERE status = 'ACTIVE' ORDER BY name ASC");

        $stagedItems = [];
        $newCount = 0;
        $updateCount = 0;
        $inSyncCount = 0;
        $reviewCount = 0;

        $nextCodeSeq = $maxSequence + 1;

        foreach ($rawItems as $raw) {
            $tallyName = $raw['tally_name'];
            $rate = (float)$raw['rate'];
            $normKey = self::normalizeKey($tallyName);
            $excelUnit = !empty($raw['unit']) ? $raw['unit'] : self::detectUnit($tallyName);

            // Validation check
            if (empty($tallyName) || strlen($tallyName) < 2) {
                $stagedItems[] = [
                    'action'          => 'NEEDS_REVIEW',
                    'reason'          => 'Invalid or empty item name',
                    'tally_name'      => $tallyName,
                    'existing_id'     => null,
                    'code'            => '',
                    'category_id'     => null,
                    'unit'            => $excelUnit ?: 'Pcs',
                    'rate'            => $rate,
                    'old_rate'        => null,
                    'closing_qty'     => $raw['closing_qty']
                ];
                $reviewCount++;
                continue;
            }

            // Match against existing database material
            $matched = $tallyMap[$normKey] ?? $nameMap[$normKey] ?? null;

            if ($matched) {
                $oldRate = (float)$matched['default_rate'];
                $isRateChanged = abs($oldRate - $rate) > 0.009 && $rate > 0;
                $isUnitChanged = !empty($excelUnit) && strcasecmp($excelUnit, $matched['unit']) !== 0;

                // Priority: Use unit from Excel if provided, else fallback to existing material unit
                $finalUnit = !empty($excelUnit) ? $excelUnit : $matched['unit'];

                if ($isRateChanged) {
                    $stagedItems[] = [
                        'action'          => 'UPDATE_RATE',
                        'reason'          => 'Rate changed in Tally (₹ ' . number_format($oldRate, 2) . ' ➔ ₹ ' . number_format($rate, 2) . ')',
                        'tally_name'      => $tallyName,
                        'name'            => $matched['name'],
                        'existing_id'     => (int)$matched['id'],
                        'code'            => $matched['code'],
                        'category_id'     => $matched['category_id'],
                        'unit'            => $finalUnit,
                        'rate'            => $rate,
                        'old_rate'        => $oldRate,
                        'closing_qty'     => $raw['closing_qty']
                    ];
                    $updateCount++;
                } else {
                    $stagedItems[] = [
                        'action'          => 'IN_SYNC',
                        'reason'          => $isUnitChanged ? "Unit updated to {$finalUnit}" : 'Matches existing catalog item perfectly',
                        'tally_name'      => $tallyName,
                        'name'            => $matched['name'],
                        'existing_id'     => (int)$matched['id'],
                        'code'            => $matched['code'],
                        'category_id'     => $matched['category_id'],
                        'unit'            => $finalUnit,
                        'rate'            => $oldRate,
                        'old_rate'        => $oldRate,
                        'closing_qty'     => $raw['closing_qty']
                    ];
                    $inSyncCount++;
                }
            } else {
                // New Material to Insert
                $autoCode = 'MAT-' . str_pad((string)$nextCodeSeq, 4, '0', STR_PAD_LEFT);
                $nextCodeSeq++;
                $autoCatId = self::detectCategory($tallyName, $categories);

                $stagedItems[] = [
                    'action'          => 'NEW_ITEM',
                    'reason'          => 'New item created in Tally',
                    'tally_name'      => $tallyName,
                    'name'            => $tallyName,
                    'existing_id'     => null,
                    'code'            => $autoCode,
                    'category_id'     => $autoCatId,
                    'unit'            => $excelUnit ?: 'Pcs',
                    'rate'            => $rate > 0 ? $rate : 0.0,
                    'old_rate'        => null,
                    'closing_qty'     => $raw['closing_qty']
                ];
                $newCount++;
            }
        }

        return [
            'total_tally_items' => count($rawItems),
            'new_items_count'   => $newCount,
            'rate_update_count' => $updateCount,
            'in_sync_count'     => $inSyncCount,
            'review_count'      => $reviewCount,
            'categories'        => $categories,
            'staged_items'      => $stagedItems
        ];
    }

    /**
     * Commit Approved Staged Items to Database Catalog
     *
     * @param array $items Array of approved items to synchronize
     * @param int $adminUserId ID of admin executing the sync
     * @return array Sync execution summary
     */
    public static function executeSync(array $items, int $adminUserId): array {
        if (empty($items)) {
            throw new Exception("No items provided for synchronization.");
        }

        // 1. Ensure current_stock column exists in materials table (DDL executed outside transaction)
        try {
            $dbConn = Database::getConnection();
            $cols = Database::query("SHOW COLUMNS FROM materials LIKE 'current_stock'");
            if (empty($cols)) {
                $dbConn->exec("ALTER TABLE materials ADD COLUMN current_stock DECIMAL(12, 3) NOT NULL DEFAULT 0.000 AFTER default_rate");
            }
        } catch (Throwable $e) {
            // Ignore if column exists
        }

        return Database::transaction(function (PDO $db) use ($items, $adminUserId) {
            $inserted = 0;
            $updated = 0;
            $errors = [];

            // Prepared statement for inserting new material with current stock
            $insertStmt = $db->prepare("
                INSERT INTO materials (name, code, category_id, unit, default_rate, current_stock, tally_item_name, tally_item_code, status, created_at)
                VALUES (:name, :code, :category_id, :unit, :rate, :current_stock, :tally_name, :tally_code, 'ACTIVE', NOW())
            ");

            // Prepared statement for updating existing material rate, stock & mapping
            $updateStmt = $db->prepare("
                UPDATE materials 
                SET default_rate = :rate,
                    current_stock = :current_stock,
                    tally_item_name = :tally_name,
                    unit = COALESCE(:unit, unit),
                    category_id = COALESCE(:category_id, category_id),
                    updated_at = NOW()
                WHERE id = :id
            ");

            // Check and generate unique codes dynamically
            $maxSeqStmt = $db->query("SELECT MAX(CAST(SUBSTRING(code, 5) AS UNSIGNED)) AS max_seq FROM materials WHERE code LIKE 'MAT-%'");
            $maxRow = $maxSeqStmt->fetch(PDO::FETCH_ASSOC);
            $currSeq = (int)($maxRow['max_seq'] ?? 0);

            foreach ($items as $idx => $it) {
                $action = $it['action'] ?? '';
                $name = trim((string)($it['name'] ?? $it['tally_name'] ?? ''));
                $tallyName = trim((string)($it['tally_name'] ?? $name));
                $unit = trim((string)($it['unit'] ?? 'Pcs'));
                $rate = (float)($it['rate'] ?? 0.0);
                $stock = isset($it['closing_qty']) ? (float)$it['closing_qty'] : 0.0;
                $catId = !empty($it['category_id']) ? (int)$it['category_id'] : null;

                if (empty($name)) {
                    $errors[] = "Row #" . ($idx + 1) . ": Name cannot be empty.";
                    continue;
                }

                if ($action === 'NEW_ITEM') {
                    $currSeq++;
                    $code = 'MAT-' . str_pad((string)$currSeq, 4, '0', STR_PAD_LEFT);

                    try {
                        $insertStmt->execute([
                            ':name'          => $name,
                            ':code'          => $code,
                            ':category_id'   => $catId,
                            ':unit'          => $unit,
                            ':rate'          => $rate,
                            ':current_stock' => $stock,
                            ':tally_name'    => $tallyName,
                            ':tally_code'    => $code
                        ]);
                        $inserted++;
                    } catch (Throwable $e) {
                        $errors[] = "Item '{$name}': " . $e->getMessage();
                    }
                } elseif ($action === 'UPDATE_RATE' || $action === 'IN_SYNC') {
                    $matId = (int)($it['existing_id'] ?? 0);
                    if ($matId <= 0) continue;

                    try {
                        $updateStmt->execute([
                            ':rate'          => $rate,
                            ':current_stock' => $stock,
                            ':tally_name'    => $tallyName,
                            ':unit'          => $unit,
                            ':category_id'   => $catId,
                            ':id'            => $matId
                        ]);
                        $updated++;
                    } catch (Throwable $e) {
                        $errors[] = "Item #{$matId}: " . $e->getMessage();
                    }
                }
            }

            Logger::logActivity($adminUserId, 'TALLY_MATERIAL_SYNC', 'materials', 'BULK_SYNC', null, [
                'inserted_count' => $inserted,
                'updated_count'  => $updated,
                'error_count'    => count($errors)
            ]);

            return [
                'inserted_count' => $inserted,
                'updated_count'  => $updated,
                'error_count'    => count($errors),
                'errors'         => $errors
            ];
        });
    }

    /**
     * Normalize string for fuzzy/exact key matching
     */
    private static function normalizeKey(string $str): string {
        $clean = preg_replace('/[^a-zA-Z0-9]/', '', $str);
        return strtolower(trim((string)$clean));
    }

    /**
     * Auto-detect unit from item name if specified
     */
    private static function detectUnit(string $name): string {
        $n = strtolower($name);
        if (preg_match('/\b(sqmm|sq\.mm|mtr|meter|mtrs)\b/', $n)) return 'Mtr';
        if (preg_match('/\b(ltr|litre|litres|mobil|oil)\b/', $n)) return 'Ltr';
        if (preg_match('/\b(kg|kgs|kilogram)\b/', $n)) return 'Kg';
        if (preg_match('/\b(bag|bags|cement)\b/', $n)) return 'Bag';
        if (preg_match('/\b(set|sets|pair)\b/', $n)) return 'Set';
        if (preg_match('/\b(box|boxes|pkt|packet)\b/', $n)) return 'Box';
        if (preg_match('/\b(roll|rolls)\b/', $n)) return 'Roll';
        if (preg_match('/\b(sheet|sheets)\b/', $n)) return 'Sheet';
        if (preg_match('/\b(bundle|bundles)\b/', $n)) return 'Bundle';
        if (preg_match('/\b(nos|no|piece|pieces|plate|mcb|light|socket|connector)\b/', $n)) return 'Pcs';
        return 'Pcs';
    }

    /**
     * Normalize unit string from Tally Excel cell
     */
    public static function normalizeUnit(string $unitRaw, string $itemName = ''): string {
        $u = strtolower(trim($unitRaw));
        $u = trim($u, "./ \t\n\r\0\x0B");

        if (in_array($u, ['mtr', 'meter', 'meters', 'mtrs', 'm'])) return 'Mtr';
        if (in_array($u, ['pcs', 'pc', 'piece', 'pieces', 'nos', 'no', 'num', 'numbers'])) return 'Pcs';
        if (in_array($u, ['ltr', 'litre', 'litres', 'liter', 'liters', 'l'])) return 'Ltr';
        if (in_array($u, ['kg', 'kgs', 'kilogram', 'kilograms'])) return 'Kg';
        if (in_array($u, ['gm', 'gms', 'gram', 'grams', 'g'])) return 'Gm';
        if (in_array($u, ['ml', 'millilitre', 'milliliter'])) return 'Ml';
        if (in_array($u, ['bag', 'bags'])) return 'Bag';
        if (in_array($u, ['set', 'sets'])) return 'Set';
        if (in_array($u, ['box', 'boxes'])) return 'Box';
        if (in_array($u, ['roll', 'rolls'])) return 'Roll';
        if (in_array($u, ['pkt', 'packet', 'packets', 'pack', 'packs'])) return 'Pkt';
        if (in_array($u, ['sqft', 'sq.ft', 'sq ft', 'sft'])) return 'Sqft';
        if (in_array($u, ['sqmtr', 'sq.mtr', 'sq mtr', 'sqm'])) return 'Sqmtr';
        if (in_array($u, ['rft', 'r.ft', 'r ft'])) return 'Rft';
        if (in_array($u, ['bun', 'bundle', 'bundles'])) return 'Bundle';
        if (in_array($u, ['bucket', 'bkt', 'buckets'])) return 'Bucket';
        if (in_array($u, ['sheet', 'sheets'])) return 'Sheet';
        if (in_array($u, ['pair', 'pairs'])) return 'Pair';

        if (!empty($u)) {
            return ucfirst($u);
        }

        // Fallback: detect from item name
        return self::detectUnit($itemName);
    }

    /**
     * Auto-detect material category ID from keywords
     */
    private static function detectCategory(string $name, array $categories): ?int {
        $n = strtolower($name);
        foreach ($categories as $cat) {
            $catName = strtolower($cat['name']);
            if (strpos($n, $catName) !== false) {
                return (int)$cat['id'];
            }
        }
        return null;
    }
}
