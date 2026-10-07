<?php

namespace App\Services\FixedAssets;

use App\Services\OperationalAuditService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Physical count of fixed assets. start() snapshots the live register (optionally one branch),
 * scan() ticks an asset off by code / barcode / serial, close() turns what was not seen into "missing".
 * An asset scanned that is not part of the snapshot (another branch) is added as "extra".
 */
final class AssetCountService
{
    public function __construct(private readonly OperationalAuditService $audit) {}

    public function start(Request $request, int $tenantId, ?int $actorId, array $data): int
    {
        return DB::transaction(function () use ($request, $tenantId, $actorId, $data): int {
            $branchId = ! empty($data['branchId']) ? (int) $data['branchId'] : null;
            if ($branchId !== null && ! DB::table('branches')->where('tenant_id', $tenantId)->where('id', $branchId)->whereNull('deleted_at')->exists()) {
                throw ValidationException::withMessages(['branchId' => 'الفرع غير موجود.']);
            }
            $assets = DB::table('fixed_assets')->where('tenant_id', $tenantId)->whereIn('status', ['active', 'fully_depreciated'])->whereNull('deleted_at')
                ->when($branchId !== null, fn ($q) => $q->where('branch_id', $branchId))->orderBy('code')->get(['id', 'code', 'name_ar', 'branch_id']);
            if ($assets->isEmpty()) {
                throw ValidationException::withMessages(['branchId' => 'لا توجد أصول فعّالة للجرد.']);
            }
            $now = now();
            $id = (int) DB::table('asset_counts')->insertGetId([
                'tenant_id' => $tenantId, 'count_number' => DocumentNumber::next($tenantId, 'asset_counts', 'count_number', 'CNT-'),
                'branch_id' => $branchId, 'count_date' => $data['countDate'] ?? $now->toDateString(), 'status' => 'open',
                'notes' => $data['notes'] ?? null, 'created_by' => $actorId, 'created_at' => $now, 'updated_at' => $now,
            ]);
            foreach ($assets->chunk(500) as $chunk) {
                DB::table('asset_count_lines')->insert($chunk->map(fn ($a) => [
                    'tenant_id' => $tenantId, 'asset_count_id' => $id, 'fixed_asset_id' => $a->id, 'expected_branch_id' => $a->branch_id,
                    'asset_code' => $a->code, 'asset_name' => $a->name_ar, 'status' => 'pending', 'created_at' => $now, 'updated_at' => $now,
                ])->all());
            }
            $this->audit->record($request, $tenantId, 'asset_count.started', 'asset_count', $id, [], ['lines' => $assets->count()], $branchId, $actorId);

            return $id;
        });
    }

    /** @return array{line: array, result: string} */
    public function scan(int $tenantId, int $countId, string $code): array
    {
        return DB::transaction(function () use ($tenantId, $countId, $code): array {
            $count = $this->open($tenantId, $countId);
            $code = trim($code);
            $asset = DB::table('fixed_assets')->where('tenant_id', $tenantId)->whereNull('deleted_at')
                ->where(fn ($q) => $q->where('code', $code)->orWhere('barcode', $code)->orWhere('serial_number', $code))
                ->whereIn('status', ['active', 'fully_depreciated'])->first(['id', 'code', 'name_ar', 'branch_id']);
            if (! $asset) {
                throw ValidationException::withMessages(['code' => 'لا يوجد أصل فعّال بهذا الكود/الباركود.']);
            }
            $line = DB::table('asset_count_lines')->where('asset_count_id', $count->id)->where('fixed_asset_id', $asset->id)->lockForUpdate()->first();
            $now = now();
            if ($line) {
                $result = $line->status === 'found' ? 'already' : 'found';
                if ($line->status !== 'found') {
                    DB::table('asset_count_lines')->where('id', $line->id)->update(['status' => 'found', 'counted_at' => $now, 'updated_at' => $now]);
                }
            } else {
                $result = 'extra';
                $lineId = (int) DB::table('asset_count_lines')->insertGetId([
                    'tenant_id' => $tenantId, 'asset_count_id' => $count->id, 'fixed_asset_id' => $asset->id, 'expected_branch_id' => $asset->branch_id,
                    'asset_code' => $asset->code, 'asset_name' => $asset->name_ar, 'status' => 'extra', 'counted_at' => $now,
                    'note' => 'أصل من خارج نطاق الجرد (فرع آخر)', 'created_at' => $now, 'updated_at' => $now,
                ]);
                $line = DB::table('asset_count_lines')->where('id', $lineId)->first();
            }

            return ['result' => $result, 'line' => $this->lineView(DB::table('asset_count_lines')->where('id', $line->id)->first())];
        });
    }

    public function setLine(int $tenantId, int $countId, int $lineId, array $data): array
    {
        $this->open($tenantId, $countId);
        $line = DB::table('asset_count_lines')->where('asset_count_id', $countId)->where('id', $lineId)->first();
        abort_unless($line, 404, 'السطر غير موجود.');
        $update = ['updated_at' => now()];
        if (isset($data['status'])) {
            $update['status'] = $data['status'];
            $update['counted_at'] = $data['status'] === 'pending' ? null : now();
        }
        if (array_key_exists('note', $data)) {
            $update['note'] = $data['note'];
        }
        DB::table('asset_count_lines')->where('id', $lineId)->update($update);

        return $this->lineView(DB::table('asset_count_lines')->where('id', $lineId)->first());
    }

    public function close(Request $request, int $tenantId, int $countId, ?int $actorId): void
    {
        DB::transaction(function () use ($request, $tenantId, $countId, $actorId): void {
            $count = $this->open($tenantId, $countId);
            DB::table('asset_count_lines')->where('asset_count_id', $count->id)->where('status', 'pending')->update(['status' => 'missing', 'updated_at' => now()]);
            DB::table('asset_counts')->where('id', $count->id)->update(['status' => 'closed', 'closed_at' => now(), 'updated_at' => now()]);
            $this->audit->record($request, $tenantId, 'asset_count.closed', 'asset_count', $count->id, [], [], $count->branch_id ? (int) $count->branch_id : null, $actorId);
        });
    }

    public function cancel(int $tenantId, int $countId): void
    {
        $count = $this->open($tenantId, $countId);
        DB::table('asset_counts')->where('id', $count->id)->update(['status' => 'cancelled', 'updated_at' => now()]);
    }

    public function list(int $tenantId): array
    {
        return DB::table('asset_counts as c')->leftJoin('branches as b', 'b.id', '=', 'c.branch_id')->where('c.tenant_id', $tenantId)
            ->orderByDesc('c.id')->get(['c.*', 'b.name as branch_name'])->map(fn ($c) => $this->view($c, $this->summary((int) $c->id)))->values()->all();
    }

    public function show(int $tenantId, int $countId): array
    {
        $c = DB::table('asset_counts as c')->leftJoin('branches as b', 'b.id', '=', 'c.branch_id')->where('c.tenant_id', $tenantId)->where('c.id', $countId)->first(['c.*', 'b.name as branch_name']);
        abort_unless($c, 404, 'الجرد غير موجود.');
        $lines = DB::table('asset_count_lines')->where('asset_count_id', $countId)->orderBy('asset_code')->get()->map(fn ($l) => $this->lineView($l))->values()->all();

        return $this->view($c, $this->summary($countId)) + ['lines' => $lines];
    }

    private function open(int $tenantId, int $countId): object
    {
        $count = DB::table('asset_counts')->where('tenant_id', $tenantId)->where('id', $countId)->lockForUpdate()->first();
        abort_unless($count, 404, 'الجرد غير موجود.');
        if ($count->status !== 'open') {
            throw ValidationException::withMessages(['count' => 'هذا الجرد مغلق.']);
        }

        return $count;
    }

    private function summary(int $countId): array
    {
        $by = DB::table('asset_count_lines')->where('asset_count_id', $countId)->selectRaw('status, COUNT(*) n')->groupBy('status')->pluck('n', 'status')->all();
        $total = array_sum($by);

        return ['total' => $total, 'found' => (int) ($by['found'] ?? 0), 'pending' => (int) ($by['pending'] ?? 0), 'missing' => (int) ($by['missing'] ?? 0), 'extra' => (int) ($by['extra'] ?? 0)];
    }

    private function view(object $c, array $summary): array
    {
        return ['id' => (int) $c->id, 'number' => $c->count_number, 'branchId' => $c->branch_id ? (int) $c->branch_id : null, 'branchName' => $c->branch_name ?? null,
            'countDate' => $c->count_date, 'status' => $c->status, 'notes' => $c->notes, 'closedAt' => $c->closed_at ? (string) $c->closed_at : null, 'summary' => $summary];
    }

    private function lineView(object $l): array
    {
        return ['id' => (int) $l->id, 'assetId' => (int) $l->fixed_asset_id, 'code' => $l->asset_code, 'name' => $l->asset_name, 'status' => $l->status,
            'note' => $l->note, 'countedAt' => $l->counted_at ? (string) $l->counted_at : null];
    }
}
