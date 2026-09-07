<?php
/**
 * Tally Accounting Export & Integration Service
 * Configurable field mapper, duplicate export protection, and batch tracking
 */

require_once __DIR__ . '/../core/Database.php';
require_once __DIR__ . '/../core/Logger.php';
require_once __DIR__ . '/../config/config.php';
require_once __DIR__ . '/SequenceService.php';

class TallyService {
    /**
     * Preview exportable records for Tally
     */
    public static function getExportPreview(
        string $dateFrom,
        string $dateTo,
        ?int $userId = null,
        ?int $locationId = null,
        string $exportFilter = 'NOT_EXPORTED' // 'NOT_EXPORTED', 'EXPORTED', 'ALL'
    ): array {
        $params = [
            ':from' => $dateFrom,
            ':to'   => $dateTo
        ];

        $where = ["r.requisition_date BETWEEN :from AND :to", "i.status IN ('ISSUED', 'PARTIALLY_ISSUED')", "i.issued_quantity > 0"];

        if ($userId) {
            $where[] = "r.user_id = :uid";
            $params[':uid'] = $userId;
        }

        if ($locationId) {
            $where[] = "s.location_id = :loc_id";
            $params[':loc_id'] = $locationId;
        }

        if ($exportFilter === 'NOT_EXPORTED') {
            $where[] = "s.tally_export_status IN ('NOT_EXPORTED', 'EXPORTED_MODIFIED')";
        } elseif ($exportFilter === 'EXPORTED') {
            $where[] = "s.tally_export_status = 'EXPORTED'";
        }

        $whereClause = implode(" AND ", $where);

        $sql = "SELECT i.id AS item_id,
                       r.id AS requisition_id,
                       r.requisition_no,
                       r.requisition_date,
                       s.id AS sub_requisition_id,
                       s.sub_requisition_no,
                       s.tally_export_status,
                       u.id AS user_id,
                       u.name AS user_name,
                       u.employee_code,
                       l.id AS location_id,
                       l.name AS location_name,
                       l.tally_ledger_name,
                       m.id AS material_id,
                       i.material_name_snapshot,
                       COALESCE(m.tally_item_name, i.material_name_snapshot) AS tally_item_name,
                       i.unit_snapshot,
                       i.requested_quantity,
                       i.issued_quantity,
                       i.unit_rate,
                       i.amount,
                       i.status AS item_status,
                       i.remark
                FROM requisition_items i
                JOIN requisition_subs s ON i.sub_requisition_id = s.id
                JOIN requisitions r ON s.requisition_id = r.id
                JOIN users u ON r.user_id = u.id
                JOIN locations l ON s.location_id = l.id
                LEFT JOIN materials m ON i.material_id = m.id
                WHERE {$whereClause}
                ORDER BY r.requisition_date ASC, s.sub_requisition_no ASC, i.id ASC";

        $items = Database::query($sql, $params);

        $salesLedger = Config::get('DEFAULT_SALES_LEDGER', 'SALE');

        $rows = [];
        $totalQuantity = 0;
        $totalAmount = 0;

        foreach ($items as $item) {
            $qty = (float) $item['issued_quantity'];
            $rate = (float) $item['unit_rate'];
            $amt = (float) $item['amount'];

            $rows[] = [
                'item_id'             => (int) $item['item_id'],
                'sub_requisition_id'  => (int) $item['sub_requisition_id'],
                'voucher_number'      => $item['sub_requisition_no'],
                'voucher_date'        => date('d-M-Y', strtotime($item['requisition_date'])),
                'raw_date'            => $item['requisition_date'],
                'party_ledger'        => $item['tally_ledger_name'] ?: $item['location_name'],
                'sales_ledger'        => $salesLedger,
                'item_name'           => $item['tally_item_name'],
                'quantity'            => $qty,
                'unit'                => $item['unit_snapshot'],
                'rate'                => $rate,
                'amount'              => $amt,
                'narration'           => "Issue to " . $item['user_name'],
                'user_name'           => $item['user_name'],
                'location_name'       => $item['location_name'],
                'export_status'       => $item['tally_export_status']
            ];

            $totalQuantity += $qty;
            $totalAmount += $amt;
        }

        return [
            'record_count'   => count($rows),
            'total_quantity' => $totalQuantity,
            'total_amount'   => $totalAmount,
            'records'        => $rows
        ];
    }

    /**
     * Generate Tally Export Batch and write CSV/Excel file
     */
    public static function generateExport(int $adminUserId, string $dateFrom, string $dateTo, array $subRequisitionIds): array {
        if (empty($subRequisitionIds)) {
            throw new Exception("No sub-requisitions selected for Tally export.");
        }

        return Database::transaction(function (PDO $db) use ($adminUserId, $dateFrom, $dateTo, $subRequisitionIds) {
            $inPlaceholders = implode(',', array_fill(0, count($subRequisitionIds), '?'));
            
            $sql = "SELECT i.*, s.id AS sub_id, s.sub_requisition_no, s.location_id,
                           r.requisition_date, u.name AS user_name,
                           l.name AS location_name, l.tally_ledger_name,
                           COALESCE(m.tally_item_name, i.material_name_snapshot) AS tally_item_name
                    FROM requisition_items i
                    JOIN requisition_subs s ON i.sub_requisition_id = s.id
                    JOIN requisitions r ON s.requisition_id = r.id
                    JOIN users u ON r.user_id = u.id
                    JOIN locations l ON s.location_id = l.id
                    LEFT JOIN materials m ON i.material_id = m.id
                    WHERE s.id IN ({$inPlaceholders})
                      AND i.status IN ('ISSUED', 'PARTIALLY_ISSUED')
                      AND i.issued_quantity > 0
                    ORDER BY s.sub_requisition_no ASC, i.id ASC";

            $stmt = $db->prepare($sql);
            $stmt->execute($subRequisitionIds);
            $items = $stmt->fetchAll();

            if (empty($items)) {
                throw new Exception("No valid issued items found for the selected sub-requisitions.");
            }

            // Create Batch
            $batchId = SequenceService::generateTallyBatchId();
            $xlsxFileName = "Tally_Sales_Voucher_{$batchId}.xlsx";
            $csvFileName = "Tally_Export_{$batchId}.csv";
            $exportDir = __DIR__ . '/../uploads/exports';
            if (!is_dir($exportDir)) {
                @mkdir($exportDir, 0755, true);
            }
            $xlsxFilePath = "{$exportDir}/{$xlsxFileName}";
            $csvFilePath = "{$exportDir}/{$csvFileName}";

            $salesLedger = Config::get('DEFAULT_SALES_LEDGER', 'SALE');

            // Group items by Sub-Requisition (Each Sub-Requisition = 1 Sales Voucher)
            $vouchers = [];
            $subIdsExported = [];

            foreach ($items as $row) {
                $sid = (int) $row['sub_id'];
                $subIdsExported[$sid] = $row['sub_requisition_no'];

                if (!isset($vouchers[$sid])) {
                    $vouchers[$sid] = [
                        'sub_id'             => $sid,
                        'sub_requisition_no' => $row['sub_requisition_no'],
                        'requisition_date'   => $row['requisition_date'],
                        'user_name'          => $row['user_name'],
                        'party_ledger'       => $row['tally_ledger_name'] ?: $row['location_name'],
                        'total_amount'       => 0.0,
                        'items'              => []
                    ];
                }
                $amt = (float) $row['amount'];
                $vouchers[$sid]['total_amount'] += $amt;
                $vouchers[$sid]['items'][] = $row;
            }

            // 1. Prepare TallyPrime Official Excel Format (Accounting Voucher Sheet) with Godown & Balanced Dr/Cr
            $xlsxHeaders = [
                'Voucher Date',
                'Voucher Type Name',
                'Voucher Number',
                'Buyer/Supplier - Address',
                'Buyer/Supplier - Pincode',
                'Ledger Name',
                'Ledger Amount',
                'Ledger Amount Dr/Cr',
                'Item Name',
                'Billed Quantity',
                'Item Rate',
                'Item Rate per',
                'Item Amount',
                'Item Allocations - Godown Name',
                'Item Allocations - Billed Quantity',
                'Item Allocations - Rate',
                'Item Allocations - Rate per',
                'Item Allocations - Amount',
                'Change Mode',
                'Voucher Narration'
            ];

            $xlsxDataRows = [];

            // 2. Prepare CSV (Excel-compatible with BOM)
            $fp = fopen($csvFilePath, 'w');
            fputs($fp, "\xEF\xBB\xBF"); // UTF-8 BOM
            fputcsv($fp, [
                'Voucher Number',
                'Voucher Date',
                'Party Ledger',
                'Sales Ledger',
                'Item Name',
                'Quantity',
                'Unit',
                'Rate',
                'Amount',
                'Godown',
                'Narration'
            ]);

            foreach ($vouchers as $vouch) {
                $formattedDate = date('d-M-Y', strtotime($vouch['requisition_date']));
                $vchNo = $vouch['sub_requisition_no'];
                $partyLedger = $vouch['party_ledger'];
                $narration = "issue to " . $vouch['user_name'];
                $totalAmount = (float) $vouch['total_amount'];

                // XLSX Row 1: Party Ledger Debit (Dr = Total Voucher Amount)
                $xlsxDataRows[] = [
                    $formattedDate,      // Voucher Date
                    'Sales',             // Voucher Type Name
                    $vchNo,              // Voucher Number
                    '',                  // Buyer/Supplier - Address
                    '',                  // Buyer/Supplier - Pincode
                    $partyLedger,        // Ledger Name
                    $totalAmount,        // Ledger Amount
                    'Dr',                // Ledger Amount Dr/Cr
                    '',                  // Item Name
                    '',                  // Billed Quantity
                    '',                  // Item Rate
                    '',                  // Item Rate per
                    '',                  // Item Amount
                    '',                  // Item Allocations - Godown Name
                    '',                  // Item Allocations - Billed Quantity
                    '',                  // Item Allocations - Rate
                    '',                  // Item Allocations - Rate per
                    '',                  // Item Allocations - Amount
                    'Item Invoice',      // Change Mode
                    $narration           // Voucher Narration
                ];

                // XLSX Rows 2..N: Sales Ledger Credit (Cr) with Godown 'Main Location'
                foreach ($vouch['items'] as $item) {
                    $qty = (float) $item['issued_quantity'];
                    $rate = (float) $item['unit_rate'];
                    $amt = (float) $item['amount'];

                    $xlsxDataRows[] = [
                        $formattedDate,            // Voucher Date
                        'Sales',                   // Voucher Type Name
                        $vchNo,                    // Voucher Number
                        '',                        // Buyer/Supplier - Address
                        '',                        // Buyer/Supplier - Pincode
                        $salesLedger,              // Ledger Name (SALE)
                        $amt,                      // Ledger Amount
                        'Cr',                      // Ledger Amount Dr/Cr
                        $item['tally_item_name'],  // Item Name
                        $qty,                      // Billed Quantity
                        $rate,                     // Item Rate
                        $item['unit_snapshot'],    // Item Rate per
                        $amt,                      // Item Amount
                        'Main Location',           // Item Allocations - Godown Name
                        $qty,                      // Item Allocations - Billed Quantity
                        $rate,                     // Item Allocations - Rate
                        $item['unit_snapshot'],    // Item Allocations - Rate per
                        $amt,                      // Item Allocations - Amount
                        'Item Invoice',            // Change Mode
                        $narration                 // Voucher Narration
                    ];

                    // CSV row
                    fputcsv($fp, [
                        $vchNo,
                        $formattedDate,
                        $partyLedger,
                        $salesLedger,
                        $item['tally_item_name'],
                        $qty,
                        $item['unit_snapshot'],
                        $rate,
                        $amt,
                        'Main Location',
                        $narration
                    ]);
                }
            }
            fclose($fp);

            // Write official XLSX file
            require_once __DIR__ . '/../core/XlsxWriter.php';
            XlsxWriter::create($xlsxFilePath, 'Accounting Voucher', $xlsxHeaders, $xlsxDataRows);

            // 3. Generate Native Tally XML Format (with Main Location Godown Allocations)
            $xmlFileName = "Tally_Sales_Voucher_{$batchId}.xml";
            $xmlFilePath = "{$exportDir}/{$xmlFileName}";

            $xml = '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
            $xml .= '<ENVELOPE>' . "\n";
            $xml .= '  <HEADER><TALLYREQUEST>Import Data</TALLYREQUEST></HEADER>' . "\n";
            $xml .= '  <BODY>' . "\n";
            $xml .= '    <IMPORTDATA>' . "\n";
            $xml .= '      <REQUESTDESC><REPORTNAME>Vouchers</REPORTNAME></REQUESTDESC>' . "\n";
            $xml .= '      <REQUESTDATA>' . "\n";

            foreach ($vouchers as $vouch) {
                $vDate = date('Ymd', strtotime($vouch['requisition_date']));
                $vNo = htmlspecialchars($vouch['sub_requisition_no'], ENT_XML1, 'UTF-8');
                $pLedger = htmlspecialchars($vouch['party_ledger'], ENT_XML1, 'UTF-8');
                $narr = htmlspecialchars("issue to " . $vouch['user_name'], ENT_XML1, 'UTF-8');
                $totAmt = number_format($vouch['total_amount'], 2, '.', '');

                $xml .= '        <TALLYMESSAGE xmlns:UDF="TallyUDF">' . "\n";
                $xml .= '          <VOUCHER VCHTYPE="Sales" ACTION="Create" OBJVIEW="Invoice Voucher View">' . "\n";
                $xml .= "            <DATE>{$vDate}</DATE>\n";
                $xml .= "            <VOUCHERTYPENAME>Sales</VOUCHERTYPENAME>\n";
                $xml .= "            <VOUCHERNUMBER>{$vNo}</VOUCHERNUMBER>\n";
                $xml .= "            <PARTYLEDGERNAME>{$pLedger}</PARTYLEDGERNAME>\n";
                $xml .= "            <PERSISTEDVIEW>Invoice Voucher View</PERSISTEDVIEW>\n";
                $xml .= "            <NARRATION>{$narr}</NARRATION>\n";

                // Party Debit Entry
                $xml .= "            <ALLLEDGERENTRIES.LIST>\n";
                $xml .= "              <LEDGERNAME>{$pLedger}</LEDGERNAME>\n";
                $xml .= "              <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>\n";
                $xml .= "              <AMOUNT>-{$totAmt}</AMOUNT>\n";
                $xml .= "            </ALLLEDGERENTRIES.LIST>\n";

                // Inventory Items with Main Location Godown Allocations
                foreach ($vouch['items'] as $item) {
                    $iName = htmlspecialchars($item['tally_item_name'], ENT_XML1, 'UTF-8');
                    $iQty = (float) $item['issued_quantity'];
                    $iUnit = htmlspecialchars($item['unit_snapshot'], ENT_XML1, 'UTF-8');
                    $iRate = number_format((float) $item['unit_rate'], 2, '.', '');
                    $iAmt = number_format((float) $item['amount'], 2, '.', '');
                    $sLedger = htmlspecialchars($salesLedger, ENT_XML1, 'UTF-8');

                    $xml .= "            <ALLINVENTORYENTRIES.LIST>\n";
                    $xml .= "              <STOCKITEMNAME>{$iName}</STOCKITEMNAME>\n";
                    $xml .= "              <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>\n";
                    $xml .= "              <RATE>{$iRate}/{$iUnit}</RATE>\n";
                    $xml .= "              <AMOUNT>{$iAmt}</AMOUNT>\n";
                    $xml .= "              <ACTUALQTY>{$iQty} {$iUnit}</ACTUALQTY>\n";
                    $xml .= "              <BILLEDQTY>{$iQty} {$iUnit}</BILLEDQTY>\n";
                    
                    // Godown Allocation (Main Location)
                    $xml .= "              <BATCHALLOCATIONS.LIST>\n";
                    $xml .= "                <GODOWNNAME>Main Location</GODOWNNAME>\n";
                    $xml .= "                <BATCHNAME>Primary Batch</BATCHNAME>\n";
                    $xml .= "                <AMOUNT>{$iAmt}</AMOUNT>\n";
                    $xml .= "                <ACTUALQTY>{$iQty} {$iUnit}</ACTUALQTY>\n";
                    $xml .= "                <BILLEDQTY>{$iQty} {$iUnit}</BILLEDQTY>\n";
                    $xml .= "                <RATE>{$iRate}/{$iUnit}</RATE>\n";
                    $xml .= "              </BATCHALLOCATIONS.LIST>\n";

                    // Sales Ledger Allocation
                    $xml .= "              <ACCOUNTINGALLOCATIONS.LIST>\n";
                    $xml .= "                <LEDGERNAME>{$sLedger}</LEDGERNAME>\n";
                    $xml .= "                <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>\n";
                    $xml .= "                <AMOUNT>{$iAmt}</AMOUNT>\n";
                    $xml .= "              </ACCOUNTINGALLOCATIONS.LIST>\n";
                    $xml .= "            </ALLINVENTORYENTRIES.LIST>\n";
                }

                $xml .= '          </VOUCHER>' . "\n";
                $xml .= '        </TALLYMESSAGE>' . "\n";
            }

            $xml .= '      </REQUESTDATA>' . "\n";
            $xml .= '    </IMPORTDATA>' . "\n";
            $xml .= '  </BODY>' . "\n";
            $xml .= '</ENVELOPE>';
            file_put_contents($xmlFilePath, $xml);

            // Record Batch in database
            $insBatch = $db->prepare("INSERT INTO tally_export_batches (batch_id, date_from, date_to, record_count, file_name, created_by, created_at)
                                      VALUES (:batch_id, :from, :to, :cnt, :file, :uid, NOW())");
            $insBatch->execute([
                ':batch_id' => $batchId,
                ':from'     => $dateFrom,
                ':to'       => $dateTo,
                ':cnt'      => count($items),
                ':file'     => $xlsxFileName,
                ':uid'      => $adminUserId
            ]);
            $batchDbId = (int) $db->lastInsertId();

            // Record audit links and update sub_requisitions status
            $insExport = $db->prepare("INSERT INTO tally_exports (batch_id, sub_requisition_id, voucher_number, exported_by, exported_at, status)
                                       VALUES (:bid, :sid, :vno, :uid, NOW(), 'SUCCESS')");
            $updSub = $db->prepare("UPDATE requisition_subs SET tally_export_status = 'EXPORTED' WHERE id = :id");

            foreach ($subIdsExported as $sid => $vno) {
                $insExport->execute([
                    ':bid' => $batchDbId,
                    ':sid' => $sid,
                    ':vno' => $vno,
                    ':uid' => $adminUserId
                ]);
                $updSub->execute([':id' => $sid]);
            }

            Logger::logActivity($adminUserId, 'TALLY_EXPORT_CREATED', 'tally_export_batches', (string) $batchDbId, null, [
                'batch_id'     => $batchId,
                'record_count' => count($items),
                'file_name'    => $xlsxFileName
            ]);

            return [
                'batch_id'      => $batchId,
                'file_name'     => $xlsxFileName,
                'file_url'      => "/uploads/exports/{$xlsxFileName}",
                'xml_file_name' => $xmlFileName,
                'xml_file_url'  => "/uploads/exports/{$xmlFileName}",
                'csv_file_name' => $csvFileName,
                'csv_file_url'  => "/uploads/exports/{$csvFileName}",
                'record_count'  => count($items),
                'sub_req_count' => count($subIdsExported)
            ];
        });
    }

    /**
     * List previous export batches
     */
    public static function getExportBatches(int $limit = 20): array {
        $sql = "SELECT b.*, u.name AS created_by_name 
                FROM tally_export_batches b
                JOIN users u ON b.created_by = u.id
                ORDER BY b.id DESC
                LIMIT :limit";
        $stmt = Database::getConnection()->prepare($sql);
        $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll();
    }
}
