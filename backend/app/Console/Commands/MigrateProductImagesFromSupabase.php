<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * One-time Finjan cutover tool: copies product images that are still stored
 * on Supabase Storage down to the local 'product-images-local' disk on this
 * VPS, and rewrites products.image_url to point at the local
 * /api/v1/product-images/{tenant}/{filename} endpoint (see
 * App\Services\Catalog\ProductImageStorage and
 * App\Http\Controllers\Api\Admin\Catalog\ProductCatalogController::showProductImage
 * for the two URL formats this command translates between).
 *
 * Safe by construction:
 *  - defaults to --dry-run (nothing is written anywhere unless --apply is passed)
 *  - only touches rows whose image_url matches the configured Supabase public
 *    URL prefix; every other row (already-local, or null) is left untouched
 *  - each row's file-copy + DB update happens in its own transaction, so a
 *    failure partway through never leaves a half-migrated row and never
 *    rolls back rows that already succeeded
 *  - never deletes the Supabase-side object — this only ever copies
 *
 * Usage (run via deployment/finjan/migrate-storage.sh, not directly):
 *   php artisan cafe618:migrate-product-images --dry-run
 *   php artisan cafe618:migrate-product-images --apply
 */
class MigrateProductImagesFromSupabase extends Command
{
    protected $signature = 'cafe618:migrate-product-images
        {--apply : Actually copy files and update the database. Without this flag, nothing is written.}
        {--limit=0 : Only process this many rows (0 = no limit). Useful for a first small test batch.}';

    protected $description = 'Copy product images from Supabase Storage to local disk and rewrite products.image_url (dry-run by default).';

    public function handle(): int
    {
        $apply = (bool) $this->option('apply');
        $limit = (int) $this->option('limit');

        if (! config('filesystems.disks.supabase-product-images.endpoint') || ! config('filesystems.disks.supabase-product-images.key')) {
            $this->error('SUPABASE_STORAGE_* environment variables are not set. Run this via deployment/finjan/migrate-storage.sh, which sets them for the duration of this command only.');

            return self::FAILURE;
        }

        $publicUrl = rtrim((string) config('filesystems.disks.supabase-product-images.url'), '/');
        if ($publicUrl === '') {
            $this->error('SUPABASE_STORAGE_PUBLIC_URL is not set — cannot identify which rows currently point at Supabase.');

            return self::FAILURE;
        }

        $appUrl = rtrim((string) config('app.url'), '/');

        $query = DB::table('products')
            ->whereNotNull('image_url')
            ->where('image_url', 'like', $publicUrl.'/%');

        $total = $query->count();
        $this->info("Found {$total} product row(s) whose image_url currently points at Supabase Storage ({$publicUrl}).");

        if ($total === 0) {
            $this->info('Nothing to migrate.');

            return self::SUCCESS;
        }

        if ($limit > 0) {
            $this->info("--limit={$limit}: processing only the first {$limit} row(s).");
        }

        $localDisk = Storage::disk('product-images-local');
        $remoteDisk = Storage::disk('supabase-product-images');

        $migrated = 0;
        $skipped = 0;
        $failed = 0;

        $query->orderBy('id')->when($limit > 0, fn ($q) => $q->limit($limit))
            ->chunkById(50, function ($rows) use (&$migrated, &$skipped, &$failed, $apply, $publicUrl, $appUrl, $localDisk, $remoteDisk) {
                foreach ($rows as $row) {
                    $urlPath = rawurldecode((string) parse_url($row->image_url, PHP_URL_PATH));
                    // Expected physical Supabase key, e.g. /tenants/12/products/uuid.jpg
                    $relative = ltrim(str_replace(parse_url($publicUrl, PHP_URL_PATH) ?: '', '', $urlPath), '/');

                    if (! preg_match('#^tenants/(\d+)/products/([A-Za-z0-9._-]+)$#', $relative, $m)) {
                        $this->warn("  [skip] product #{$row->id}: could not parse tenant/filename from {$row->image_url}");
                        $skipped++;

                        continue;
                    }
                    [$full, $tenantId, $filename] = $m;
                    $localPath = "product-images/{$tenantId}/{$filename}";
                    $newUrl = "{$appUrl}/api/v1/product-images/{$tenantId}/{$filename}";

                    if ($localDisk->exists($localPath)) {
                        $this->line("  [have] product #{$row->id}: {$localPath} already exists locally, will only update the URL if it differs.");
                    }

                    if (! $apply) {
                        $this->line("  [dry-run] product #{$row->id}: would copy tenants/{$tenantId}/products/{$filename} -> {$localPath}, then set image_url = {$newUrl}");
                        $migrated++;

                        continue;
                    }

                    try {
                        if (! $localDisk->exists($localPath)) {
                            if (! $remoteDisk->exists($relative)) {
                                $this->error("  [fail] product #{$row->id}: source object missing on Supabase: {$relative}");
                                $failed++;

                                continue;
                            }
                            $contents = $remoteDisk->get($relative);
                            $localDisk->put($localPath, $contents, ['visibility' => 'public']);
                        }

                        DB::transaction(function () use ($row, $newUrl) {
                            DB::table('products')->where('id', $row->id)->update(['image_url' => $newUrl]);
                        });

                        $this->info("  [ok] product #{$row->id}: migrated -> {$newUrl}");
                        $migrated++;
                    } catch (\Throwable $e) {
                        $this->error("  [fail] product #{$row->id}: {$e->getMessage()}");
                        $failed++;
                    }
                }
            });

        $this->newLine();
        $this->info("Summary: {$migrated} ".($apply ? 'migrated' : 'would be migrated').", {$skipped} skipped (unparseable URL), {$failed} failed.");

        if (! $apply) {
            $this->comment('This was a DRY RUN. No files were copied and no database rows were changed. Re-run with --apply to perform the migration.');
        }

        return $failed > 0 ? self::FAILURE : self::SUCCESS;
    }
}
