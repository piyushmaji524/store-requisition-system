<?php
/**
 * Lightweight Pure-PHP Streaming XLSX Reader
 * Zero external dependencies. Uses built-in ZipArchive and SimpleXML.
 */

class XlsxReader {
    /**
     * Read an XLSX file and return an array of rows with column-letter keys (A, B, C, ...)
     * 
     * @param string $filePath
     * @param int $sheetIndex 1-based index (default 1)
     * @return array<int, array<string, mixed>>
     */
    public static function read(string $filePath, int $sheetIndex = 1): array {
        if (!file_exists($filePath)) {
            throw new Exception("File not found: {$filePath}");
        }

        $zip = new ZipArchive();
        if ($zip->open($filePath) !== true) {
            throw new Exception("Failed to open XLSX archive. Ensure it is a valid Excel file.");
        }

        // 1. Load Shared Strings Table
        $sharedStrings = [];
        $sharedXmlContent = $zip->getFromName('xl/sharedStrings.xml');
        if ($sharedXmlContent !== false) {
            $sXml = @simplexml_load_string($sharedXmlContent);
            if ($sXml && isset($sXml->si)) {
                foreach ($sXml->si as $si) {
                    if (isset($si->t)) {
                        $sharedStrings[] = (string)$si->t;
                    } elseif (isset($si->r)) {
                        $text = '';
                        foreach ($si->r as $r) {
                            $text .= (string)$r->t;
                        }
                        $sharedStrings[] = $text;
                    } else {
                        $sharedStrings[] = '';
                    }
                }
            }
        }

        // 2. Load Worksheet XML
        $sheetXmlPath = "xl/worksheets/sheet{$sheetIndex}.xml";
        $sheetXmlContent = $zip->getFromName($sheetXmlPath);
        if ($sheetXmlContent === false) {
            // Try looking up workbook.xml to find first sheet relationship
            $sheetXmlContent = $zip->getFromName('xl/worksheets/sheet1.xml');
            if ($sheetXmlContent === false) {
                $zip->close();
                throw new Exception("Sheet {$sheetIndex} not found in workbook.");
            }
        }

        $rows = [];
        $wXml = @simplexml_load_string($sheetXmlContent);
        if ($wXml && isset($wXml->sheetData->row)) {
            foreach ($wXml->sheetData->row as $r) {
                $rowNum = (int)$r['r'];
                $rowCells = [];

                if (isset($r->c)) {
                    foreach ($r->c as $c) {
                        $cellRef = (string)$c['r'];
                        // Extract column letters (e.g. A, B, AA)
                        $col = preg_replace('/[0-9]/', '', $cellRef);
                        $type = (string)$c['t'];
                        $val = (string)$c->v;

                        if ($type === 's') {
                            // Shared String
                            $val = $sharedStrings[(int)$val] ?? '';
                        } elseif ($type === 'inlineStr' && isset($c->is->t)) {
                            // Inline String
                            $val = (string)$c->is->t;
                        }

                        $rowCells[$col] = $val;
                    }
                }

                $rows[$rowNum] = $rowCells;
            }
        }

        $zip->close();
        return $rows;
    }
}
