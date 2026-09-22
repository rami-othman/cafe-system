<?php

namespace App\Services\Customer\Import;

use App\Domain\Customer\CustomerNameNormalizer;
use App\Domain\Customer\CustomerPhoneNormalizer;
use Illuminate\Http\UploadedFile;

final class CustomerCsvImportParser
{
    public const MAX_BYTES = 5_242_880;
    public const MAX_ROWS = 50_000;

    /** @return array{fingerprint:string, encoding:string, delimiter:string, rows:array<int,array<string,mixed>>} */
    public function parse(UploadedFile $file): array
    {
        $size = $file->getSize();
        if ($size !== false && $size > self::MAX_BYTES) {
            throw CustomerImportException::invalidFile('CUSTOMER_IMPORT_FILE_TOO_LARGE');
        }

        $bytes = file_get_contents($file->getRealPath());
        if ($bytes === false) {
            throw CustomerImportException::invalidFile('CUSTOMER_IMPORT_INVALID_FILE');
        }

        return $this->parseBytes($bytes, $file->getClientOriginalName());
    }

    /** @return array{fingerprint:string, encoding:string, delimiter:string, rows:array<int,array<string,mixed>>} */
    public function parseBytes(string $bytes, string $filename = 'customers.csv'): array
    {
        if (strlen($bytes) > self::MAX_BYTES) {
            throw CustomerImportException::invalidFile('CUSTOMER_IMPORT_FILE_TOO_LARGE');
        }
        if ($bytes === '' || str_contains($bytes, "\0") || str_starts_with($bytes, "\xFF\xFE") || str_starts_with($bytes, "\xFE\xFF")) {
            throw CustomerImportException::invalidFile('CUSTOMER_IMPORT_UNSUPPORTED_ENCODING');
        }

        [$text, $encoding] = $this->decode($bytes);
        $records = $this->records($text);
        if ($records === []) {
            throw CustomerImportException::invalidFile('CUSTOMER_IMPORT_REQUIRED_COLUMN_MISSING');
        }

        $headerIndex = null;
        foreach ($records as $index => $record) {
            if (trim($record['text']) !== '') {
                $headerIndex = $index;
                break;
            }
        }
        if ($headerIndex === null) {
            throw CustomerImportException::invalidFile('CUSTOMER_IMPORT_REQUIRED_COLUMN_MISSING');
        }

        $delimiter = $this->detectDelimiter($records[$headerIndex]['text']);
        $headers = str_getcsv($records[$headerIndex]['text'], $delimiter, '"', '"');
        $mapping = $this->mapHeaders($headers);
        $rows = [];

        foreach (array_slice($records, $headerIndex + 1) as $record) {
            if (trim($record['text']) === '') {
                continue;
            }
            $fields = str_getcsv($record['text'], $delimiter, '"', '"');
            $row = $this->parseRow($fields, $mapping, (int) $record['line']);
            $rows[] = $row;
            if (count($rows) > self::MAX_ROWS) {
                throw CustomerImportException::invalidFile('CUSTOMER_IMPORT_TOO_MANY_ROWS');
            }
        }

        return [
            'fingerprint' => hash('sha256', $bytes),
            'encoding' => $encoding,
            'delimiter' => $delimiter,
            'rows' => $rows,
        ];
    }

    /** @return array{0:string,1:string} */
    private function decode(string $bytes): array
    {
        if (str_starts_with($bytes, "\xEF\xBB\xBF")) {
            return [substr($bytes, 3), 'UTF-8 BOM'];
        }
        if (mb_check_encoding($bytes, 'UTF-8')) {
            return [$bytes, 'UTF-8'];
        }
        if (preg_match('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/', $bytes)) {
            throw CustomerImportException::invalidFile('CUSTOMER_IMPORT_UNSUPPORTED_ENCODING');
        }
        $converted = iconv('Windows-1256', 'UTF-8//IGNORE', $bytes);
        if ($converted === false || ! mb_check_encoding($converted, 'UTF-8')) {
            throw CustomerImportException::invalidFile('CUSTOMER_IMPORT_UNSUPPORTED_ENCODING');
        }

        return [$converted, 'Windows-1256'];
    }

    /** @return list<array{text:string,line:int}> */
    private function records(string $text): array
    {
        $records = [];
        $buffer = '';
        $inQuotes = false;
        $line = 1;
        $recordLine = 1;
        $length = strlen($text);
        for ($i = 0; $i < $length; $i++) {
            $character = $text[$i];
            if ($character === '"') {
                if ($inQuotes && $i + 1 < $length && $text[$i + 1] === '"') {
                    $buffer .= '""';
                    $i++;
                    continue;
                }
                $inQuotes = ! $inQuotes;
                $buffer .= $character;
                continue;
            }
            if ($character === "\n") {
                if (! $inQuotes) {
                    $records[] = ['text' => rtrim($buffer, "\r"), 'line' => $recordLine];
                    $buffer = '';
                    $line++;
                    $recordLine = $line;
                    continue;
                }
                $line++;
            }
            $buffer .= $character;
        }
        if ($inQuotes) {
            throw CustomerImportException::invalidFile('CUSTOMER_IMPORT_INVALID_FILE');
        }
        if ($buffer !== '') {
            $records[] = ['text' => rtrim($buffer, "\r"), 'line' => $recordLine];
        }

        return $records;
    }

    private function detectDelimiter(string $header): string
    {
        $scores = [];
        foreach ([',', ';', "\t"] as $delimiter) {
            $scores[$delimiter] = count(str_getcsv($header, $delimiter, '"', '"'));
        }
        arsort($scores);
        $top = array_key_first($scores);
        $values = array_values($scores);
        if ($top === null || ($values[0] ?? 0) < 2 || (($values[0] ?? 0) === ($values[1] ?? 0))) {
            throw CustomerImportException::invalidFile('CUSTOMER_IMPORT_DELIMITER_UNDETECTABLE');
        }

        return $top;
    }

    /** @return array<string,int> */
    private function mapHeaders(array $headers): array
    {
        $mapping = [];
        foreach ($headers as $index => $header) {
            $key = $this->headerKey((string) $header);
            if ($key === null) {
                continue;
            }
            if (array_key_exists($key, $mapping)) {
                throw CustomerImportException::invalidFile('CUSTOMER_IMPORT_AMBIGUOUS_COLUMNS');
            }
            $mapping[$key] = (int) $index;
        }
        if (! array_key_exists('name', $mapping)) {
            throw CustomerImportException::invalidFile('CUSTOMER_IMPORT_REQUIRED_COLUMN_MISSING');
        }

        return $mapping;
    }

    private function headerKey(string $header): ?string
    {
        $header = mb_strtolower(trim(preg_replace('/\s+/u', ' ', $header) ?? $header), 'UTF-8');
        $aliases = [
            'name' => ['name', 'customer name', "\u{0627}\u{0644}\u{0627}\u{0633}\u{0645}"],
            'phoneOne' => ['phone', 'phone 1', 'telephone', "\u{0647}\u{0627}\u{062a}\u{0641} 1"],
            'mobile' => ['mobile', 'cell', "\u{062e}\u{0644}\u{064a}\u{0648}\u{064a}"],
            'group' => ['group', 'customer group', "\u{0627}\u{0644}\u{0645}\u{062c}\u{0645}\u{0648}\u{0639}\u{0629}"],
            'legacyCustomerNumber' => ['customer number', 'legacy customer number', "\u{0631}\u{0642}\u{0645} \u{0627}\u{0644}\u{0639}\u{0645}\u{064a}\u{0644}"],
            'legacyAccountCode' => ['account code', 'account number', "\u{0631}\u{0645}\u{0632} \u{0627}\u{0644}\u{062d}\u{0633}\u{0627}\u{0628}"],
        ];
        foreach ($aliases as $key => $values) {
            if (in_array($header, $values, true)) {
                return $key;
            }
        }

        return null;
    }

    /** @return array<string,mixed> */
    private function parseRow(array $fields, array $mapping, int $sourceRowNumber): array
    {
        $value = static fn (string $key): string => trim((string) ($fields[$mapping[$key]] ?? ''));
        $sourceName = $value('name');
        $name = CustomerNameNormalizer::normalize($sourceName);
        $warnings = [];
        $errors = [];
        if ($name['displayName'] === '' || $name['normalizedName'] === '' || mb_strlen($name['displayName'], 'UTF-8') > 255) {
            $errors[] = 'MISSING_OR_INVALID_NAME';
        }

        $phoneCandidates = [];
        foreach (['phoneOne', 'mobile'] as $key) {
            if (! array_key_exists($key, $mapping)) {
                continue;
            }
            $raw = $value($key);
            if ($raw === '') {
                continue;
            }
            $normalized = CustomerPhoneNormalizer::normalize($raw);
            if ($normalized['normalizedNumber'] === null || $normalized['validationStatus'] === 'invalid') {
                $warnings[] = 'INVALID_PHONE_IGNORED';
                continue;
            }
            if (in_array($normalized['normalizedNumber'], array_column($phoneCandidates, 'normalizedNumber'), true)) {
                $warnings[] = 'DUPLICATE_PHONE_IN_ROW';
                continue;
            }
            $phoneCandidates[] = [
                'rawNumber' => $normalized['rawNumber'],
                'normalizedNumber' => $normalized['normalizedNumber'],
                'validationStatus' => $normalized['validationStatus'],
                'type' => $key === 'mobile' ? 'mobile' : 'phone',
            ];
        }
        $primaryIndex = null;
        foreach ($phoneCandidates as $index => $phone) {
            if ($phone['type'] === 'mobile') {
                $primaryIndex = $index;
                break;
            }
        }
        $primaryIndex ??= $phoneCandidates === [] ? null : 0;
        foreach ($phoneCandidates as $index => &$phone) {
            $phone['isPrimary'] = $index === $primaryIndex;
        }
        unset($phone);

        $group = array_key_exists('group', $mapping) ? $value('group') : '';
        $groupNormalized = $group === '' ? null : CustomerNameNormalizer::normalize($group)['normalizedName'];
        $payload = [
            'displayName' => $name['displayName'],
            'normalizedName' => $name['normalizedName'],
            'phones' => $phoneCandidates,
            'groupName' => $group === '' ? null : $group,
            'groupNormalizedName' => $groupNormalized,
        ];

        return [
            'sourceRowNumber' => $sourceRowNumber,
            'legacyCustomerNumber' => array_key_exists('legacyCustomerNumber', $mapping) ? $value('legacyCustomerNumber') : null,
            'legacyAccountCode' => array_key_exists('legacyAccountCode', $mapping) ? $value('legacyAccountCode') : null,
            'sourceName' => $sourceName,
            'normalizedName' => $name['normalizedName'],
            'sourcePhoneOne' => array_key_exists('phoneOne', $mapping) ? $value('phoneOne') : null,
            'sourceMobile' => array_key_exists('mobile', $mapping) ? $value('mobile') : null,
            'sourceGroup' => $group === '' ? null : $group,
            'payload' => $payload,
            'classification' => $errors === [] ? 'ready' : 'rejected',
            'status' => $errors === [] ? ($warnings === [] ? 'ready' : 'warning') : 'rejected',
            'warnings' => array_values(array_unique($warnings)),
            'errors' => array_values(array_unique($errors)),
        ];
    }
}
