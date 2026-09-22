<?php

namespace App\Jobs;

use App\Services\Customer\Import\CustomerImportService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class ProcessCustomerImportJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, SerializesModels;

    public function __construct(
        public readonly int $importId,
        public readonly int $tenantId,
        public readonly int $actorId,
    ) {}

    public function handle(CustomerImportService $service): void
    {
        $service->process($this->tenantId, $this->importId, $this->actorId);
    }
}
