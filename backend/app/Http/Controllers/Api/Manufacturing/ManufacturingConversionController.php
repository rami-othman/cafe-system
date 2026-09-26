<?php

namespace App\Http\Controllers\Api\Manufacturing;

use App\Domain\Manufacturing\ManufacturingConversionService;
use App\Domain\Manufacturing\ManufacturingDomainException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Manufacturing\ConversionRequest;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ManufacturingConversionController extends Controller
{
    public function __construct(private readonly ManufacturingConversionService $conversions) {}

    public function store(ConversionRequest $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $record = $this->conversions->convert($request, $tenantId, $request->validated(), FinancialActor::id($request, $tenantId));

        return response()->json(['data' => $record], 201);
    }

    public function show(Request $request, string $conversion): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $this->conversions->get($tenantId, is_numeric($conversion) ? (int) $conversion : $conversion);
        if (! $data) {
            throw ManufacturingDomainException::validationFailed('id', 'Conversion not found.');
        }

        return response()->json(['data' => $data]);
    }
}
