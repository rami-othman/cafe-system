<?php

namespace App\Services\Catalog;

readonly class StoredProductImage
{
    public function __construct(public string $path, public string $url) {}
}
