<?php

namespace Tests\Feature;

use App\Models\Product;
use App\Services\Catalog\ProductImageStorage;
use App\Services\Catalog\ProductImageStorageException;
use Illuminate\Filesystem\FilesystemAdapter;
use Illuminate\Filesystem\FilesystemManager;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Mockery;
use Tests\TestCase;

class ProductImageStorageTest extends TestCase
{
    use DatabaseMigrations;

    public function test_local_upload_keeps_the_legacy_public_api_url_and_tenant_path(): void
    {
        config(['product-images.disk' => 'product-images-local', 'app.url' => 'http://localhost']);
        Storage::fake('product-images-local');

        $stored = app(ProductImageStorage::class)->store(UploadedFile::fake()->create('latte.jpg', 10, 'image/jpeg'), 41);

        $this->assertMatchesRegularExpression('#^product-images/41/[0-9a-f-]+\\.jpg$#', $stored->path);
        $this->assertSame('http://localhost/api/v1/product-images/41/'.basename($stored->path), $stored->url);
        Storage::disk('product-images-local')->assertExists($stored->path);
    }

    public function test_cloud_disk_uses_a_public_https_url_and_server_derived_tenant_path(): void
    {
        config([
            'product-images.disk' => 'supabase-product-images',
            'filesystems.disks.supabase-product-images.url' => 'https://project.supabase.co/storage/v1/object/public/product-images',
        ]);
        Storage::fake('supabase-product-images');

        $stored = app(ProductImageStorage::class)->store(UploadedFile::fake()->create('ignored-client-name.png', 10, 'image/png'), 7);

        $this->assertMatchesRegularExpression('#^tenants/7/products/[0-9a-f-]+\\.png$#', $stored->path);
        $this->assertSame('https://project.supabase.co/storage/v1/object/public/product-images/'.$stored->path, $stored->url);
        Storage::disk('supabase-product-images')->assertExists($stored->path);
    }

    public function test_replacement_updates_the_product_before_removing_its_old_managed_object(): void
    {
        config([
            'product-images.disk' => 'supabase-product-images',
            'filesystems.disks.supabase-product-images.url' => 'https://project.supabase.co/storage/v1/object/public/product-images',
        ]);
        Storage::fake('supabase-product-images');
        $tenantId = $this->tenant('image-replacement');
        $oldPath = "tenants/{$tenantId}/products/old.jpg";
        $oldUrl = 'https://project.supabase.co/storage/v1/object/public/product-images/'.$oldPath;
        Storage::disk('supabase-product-images')->put($oldPath, 'old image');
        $product = Product::query()->create(['tenant_id' => $tenantId, 'name' => 'Latte', 'image_url' => $oldUrl]);

        $stored = app(ProductImageStorage::class)->replace($product, UploadedFile::fake()->create('new.jpg', 10, 'image/jpeg'));

        $this->assertDatabaseHas('products', ['id' => $product->id, 'image_url' => $stored->url]);
        Storage::disk('supabase-product-images')->assertExists($stored->path);
        Storage::disk('supabase-product-images')->assertMissing($oldPath);
    }

    public function test_failed_upload_preserves_the_existing_product_url(): void
    {
        config([
            'product-images.disk' => 'supabase-product-images',
            'filesystems.disks.supabase-product-images.url' => 'https://project.supabase.co/storage/v1/object/public/product-images',
        ]);
        $tenantId = $this->tenant('image-failure');
        $product = Product::query()->create(['tenant_id' => $tenantId, 'name' => 'Latte', 'image_url' => 'https://example.test/old.jpg']);
        $disk = Mockery::mock(FilesystemAdapter::class);
        $disk->shouldReceive('putFileAs')->once()->andReturn(false);
        $disk->shouldReceive('delete')->once();
        $storage = Mockery::mock(FilesystemManager::class);
        $storage->shouldReceive('disk')->twice()->with('supabase-product-images')->andReturn($disk);
        Storage::swap($storage);

        try {
            app(ProductImageStorage::class)->replace($product, UploadedFile::fake()->create('new.jpg', 10, 'image/jpeg'));
            $this->fail('Expected a storage exception.');
        } catch (ProductImageStorageException) {
            $this->assertDatabaseHas('products', ['id' => $product->id, 'image_url' => 'https://example.test/old.jpg']);
        }
    }

    public function test_archiving_a_product_does_not_delete_its_image(): void
    {
        config(['product-images.disk' => 'product-images-local']);
        Storage::fake('product-images-local');
        $tenantId = $this->tenant('image-archive');
        $path = "product-images/{$tenantId}/retained.jpg";
        Storage::disk('product-images-local')->put($path, 'image');
        $product = Product::query()->create(['tenant_id' => $tenantId, 'name' => 'Latte', 'image_url' => "http://localhost/api/v1/product-images/{$tenantId}/retained.jpg"]);

        $product->delete();

        Storage::disk('product-images-local')->assertExists($path);
        $this->assertSoftDeleted('products', ['id' => $product->id]);
    }

    public function test_staging_initializer_refuses_to_run_in_testing(): void
    {
        $this->artisan('staging:initialize', ['--confirm-staging' => true])
            ->expectsOutput('This command is restricted to APP_ENV=staging.')
            ->assertExitCode(1);
    }

    private function tenant(string $slug): int
    {
        $slug .= '-'.Str::lower(Str::random(8));

        return DB::table('tenants')->insertGetId(['name' => ucfirst($slug), 'slug' => $slug, 'created_at' => now(), 'updated_at' => now()]);
    }
}
