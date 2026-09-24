<?php

namespace App\Http\Controllers\Api\Admin\CustomerManagement;

use App\Http\Controllers\Controller;
use App\Http\Requests\Customer\CommitCustomerImportRequest;
use App\Http\Requests\Customer\PreviewCustomerImportRequest;
use App\Services\Customer\Import\CustomerImportService;
use Illuminate\Http\JsonResponse;

final class CustomerImportController extends Controller
{
    public function __construct(private readonly CustomerImportService $imports) {}

    public function preview(PreviewCustomerImportRequest $request): JsonResponse
    {
        return response()->json(['data' => $this->imports->serialize($this->imports->preview($request, $request->file('file')))], 201);
    }

    public function commit(CommitCustomerImportRequest $request, int $import): JsonResponse
    {
        $record = $this->imports->commit($request, $import, (bool) $request->boolean('createMissingGroups'));

        return response()->json(['data' => $this->imports->serialize($record)]);
    }

    public function show(\Illuminate\Http\Request $request, int $import): JsonResponse
    {
        return response()->json(['data' => $this->imports->serialize($this->imports->find($request, $import))]);
    }

    public function errors(\Illuminate\Http\Request $request, int $import)
    {
        return $this->imports->errors($request, $import);
    }
}
