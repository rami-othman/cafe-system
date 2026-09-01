<?php

namespace App\Services\Catalog;

use App\Models\Product;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ProductImageStorage
{
    public function store(UploadedFile $image, int $tenantId): StoredProductImage
    {
        if ($tenantId < 1) {
            throw new ProductImageStorageException('A valid tenant is required for a product image.');
        }

        $disk = Storage::disk($this->diskName());
        $filename = Str::uuid()->toString().'.'.$this->extension($image);
        $path = $this->directory($tenantId).'/'.$filename;

        try {
            if ($disk->putFileAs($this->directory($tenantId), $image, $filename, ['visibility' => 'public']) === false) {
                throw new ProductImageStorageException('The product image could not be stored.');
            }

            return new StoredProductImage($path, $this->publicUrl($tenantId, $filename, $path));
        } catch (\Throwable $exception) {
            // A partially written object must never be advertised to a client.
            $this->deletePath($path);

            if ($exception instanceof ProductImageStorageException) {
                throw $exception;
            }

            throw new ProductImageStorageException('The product image could not be stored.', previous: $exception);
        }
    }

    /**
     * Replaces a Product image atomically from the database perspective. The
     * existing object is only removed after the new URL has committed.
     */
    public function replace(Product $product, UploadedFile $image): StoredProductImage
    {
        $stored = $this->store($image, $product->tenant_id);

        try {
            $previousUrl = DB::transaction(function () use ($product, $stored): ?string {
                $locked = Product::query()
                    ->where('tenant_id', $product->tenant_id)
                    ->lockForUpdate()
                    ->findOrFail($product->id);
                $previousUrl = $locked->image_url;
                $locked->update(['image_url' => $stored->url]);

                return $previousUrl;
            });
        } catch (\Throwable $exception) {
            $this->deletePath($stored->path);

            throw new ProductImageStorageException('The product image could not be saved.', previous: $exception);
        }

        $this->deleteManagedUrl($previousUrl, $product->tenant_id);

        return $stored;
    }

    public function usesLocalDisk(): bool
    {
        return $this->diskName() === 'product-images-local';
    }

    private function diskName(): string
    {
        return (string) config('product-images.disk', env('PRODUCT_IMAGE_DISK', 'product-images-local'));
    }

    private function directory(int $tenantId): string
    {
        return $this->usesLocalDisk()
            ? "product-images/{$tenantId}"
            : "tenants/{$tenantId}/products";
    }

    private function extension(UploadedFile $image): string
    {
        return strtolower($image->extension() ?: $image->getClientOriginalExtension() ?: 'bin');
    }

    private function publicUrl(int $tenantId, string $filename, string $path): string
    {
        if ($this->usesLocalDisk()) {
            return rtrim((string) config('app.url'), '/')."/api/v1/product-images/{$tenantId}/{$filename}";
        }

        $baseUrl = rtrim((string) config("filesystems.disks.{$this->diskName()}.url"), '/');
        if (! str_starts_with($baseUrl, 'https://')) {
            throw new ProductImageStorageException('The product image public URL is not configured for HTTPS.');
        }

        return $baseUrl.'/'.$this->encodePath($path);
    }

    private function deleteManagedUrl(?string $url, int $tenantId): void
    {
        if (! $url) {
            return;
        }

        $path = null;
        if ($this->usesLocalDisk()) {
            $pathPrefix = '/api/v1/product-images/'.$tenantId.'/';
            $urlPath = (string) parse_url($url, PHP_URL_PATH);
            if (str_starts_with($urlPath, $pathPrefix)) {
                $filename = basename(substr($urlPath, strlen($pathPrefix)));
                $path = "product-images/{$tenantId}/{$filename}";
            }
        } else {
            $baseUrl = rtrim((string) config("filesystems.disks.{$this->diskName()}.url"), '/').'/';
            if (str_starts_with($url, $baseUrl)) {
                $candidate = rawurldecode(substr($url, strlen($baseUrl)));
                if (str_starts_with($candidate, "tenants/{$tenantId}/products/") && ! str_contains($candidate, '..')) {
                    $path = $candidate;
                }
            }
        }

        if ($path) {
            $this->deletePath($path);
        }
    }

    private function deletePath(string $path): void
    {
        try {
            Storage::disk($this->diskName())->delete($path);
        } catch (\Throwable) {
            // Orphan cleanup is bounded best effort. A failed cleanup must not
            // undo a successfully committed Product URL.
        }
    }

    private function encodePath(string $path): string
    {
        return implode('/', array_map(rawurlencode(...), explode('/', $path)));
    }
}
