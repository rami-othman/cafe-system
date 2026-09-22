<?php

namespace Tests\Unit\Customer;

use App\Services\Customer\Import\CustomerCsvImportParser;
use App\Services\Customer\Import\CustomerImportException;
use Tests\TestCase;

class CustomerCsvImportParserTest extends TestCase
{
    public function test_it_parses_the_windows_1256_legacy_shape_and_leading_blank_line(): void
    {
        $arabic = "\u{0627}\u{0644}\u{0627}\u{0633}\u{0645}";
        $bytes = iconv('UTF-8', 'Windows-1256', "\r\n#;\u{0631}\u{0642}\u{0645} \u{0627}\u{0644}\u{0639}\u{0645}\u{064a}\u{0644};{$arabic};\u{0647}\u{0627}\u{062a}\u{0641} 1;\u{062e}\u{0644}\u{064a}\u{0648}\u{064a};\u{0627}\u{0644}\u{0645}\u{062c}\u{0645}\u{0648}\u{0639}\u{0629}\r\n1;42;\u{0639}\u{0645}\u{064a}\u{0644} \u{062a}\u{062c}\u{0631}\u{064a}\u{0628}\u{064a};07;;\u{0645}\u{062c}\u{0645}\u{0648}\u{0639}\u{0629}\r\n");
        $result = (new CustomerCsvImportParser())->parseBytes($bytes, 'legacy.csv');

        $this->assertSame('Windows-1256', $result['encoding']);
        $this->assertSame(';', $result['delimiter']);
        $this->assertCount(1, $result['rows']);
        $this->assertSame("\u{0639}\u{0645}\u{064a}\u{0644} \u{062a}\u{062c}\u{0631}\u{064a}\u{0628}\u{064a}", $result['rows'][0]['sourceName']);
        $this->assertSame([], $result['rows'][0]['payload']['phones']);
    }

    public function test_it_supports_utf8_bom_quoted_delimiters_and_unnamed_trailing_columns(): void
    {
        $csv = "\xEF\xBB\xBFname,phone,mobile,group,,,,\r\n\"A, B\",091234567,,\"Group, One\",,,,,\r\n";
        $result = (new CustomerCsvImportParser())->parseBytes($csv);

        $this->assertSame('UTF-8 BOM', $result['encoding']);
        $this->assertSame(',', $result['delimiter']);
        $this->assertSame('A, B', $result['rows'][0]['sourceName']);
        $this->assertSame('Group, One', $result['rows'][0]['sourceGroup']);
        $this->assertSame('091234567', $result['rows'][0]['payload']['phones'][0]['normalizedNumber']);
    }

    public function test_it_supports_tab_delimiters_and_rejects_missing_or_ambiguous_names(): void
    {
        $parser = new CustomerCsvImportParser();
        $this->assertSame('Tab Name', $parser->parseBytes("name\tphone\nTab Name\t091234567\n")['rows'][0]['sourceName']);
        $this->expectException(CustomerImportException::class);
        $parser->parseBytes("name,customer name\nvalue,value\n");
    }

    public function test_it_ignores_invalid_phones_without_fabricating_a_phone(): void
    {
        $result = (new CustomerCsvImportParser())->parseBytes("name;phone;mobile\nNo Phone;07;\\\n");

        $this->assertSame([], $result['rows'][0]['payload']['phones']);
        $this->assertContains('INVALID_PHONE_IGNORED', $result['rows'][0]['warnings']);
    }

    public function test_it_enforces_row_limit(): void
    {
        $parser = new CustomerCsvImportParser();
        $csv = "name\n".str_repeat("Customer\n", CustomerCsvImportParser::MAX_ROWS + 1);

        $this->expectException(CustomerImportException::class);
        $parser->parseBytes($csv);
    }
}
