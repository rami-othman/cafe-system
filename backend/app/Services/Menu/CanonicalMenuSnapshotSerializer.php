<?php

namespace App\Services\Menu;

class CanonicalMenuSnapshotSerializer
{
    public function serialize(array $snapshot): string
    {
        return json_encode($this->normalize($snapshot), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
    }

    public function checksum(array $snapshot): string
    {
        return hash('sha256', $this->serialize($snapshot));
    }

    private function normalize(mixed $value): mixed
    {
        if (! is_array($value)) {
            return $value;
        }
        if (array_is_list($value)) {
            return array_map(fn ($item) => $this->normalize($item), $value);
        }
        ksort($value, SORT_STRING);
        foreach ($value as $key => $item) {
            $value[$key] = $this->normalize($item);
        }

        return $value;
    }
}
