<?php

namespace App\Http\Controllers\Api\Manufacturing;

use App\Domain\Manufacturing\ManufacturingDomainException;
use App\Domain\Manufacturing\ManufacturingRecipeService;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Manufacturing\RecipeRequest;
use App\Support\FinancialActor;
use App\Support\TenantContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ManufacturingRecipeController extends Controller
{
    public function __construct(private readonly ManufacturingRecipeService $recipes) {}

    public function index(Request $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);

        return response()->json(['data' => $this->recipes->list($tenantId, $request->only(['search', 'type', 'status']))]);
    }

    public function show(Request $request, int $recipe): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $data = $this->recipes->get($tenantId, $recipe);
        if (! $data) {
            throw ManufacturingDomainException::recipeNotFound();
        }

        return response()->json(['data' => $data]);
    }

    public function store(RecipeRequest $request): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $id = $this->recipes->create($request, $tenantId, $request->validated(), FinancialActor::id($request, $tenantId));

        return response()->json(['data' => $this->recipes->get($tenantId, $id)], 201);
    }

    public function update(RecipeRequest $request, int $recipe): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $id = $this->recipes->update($request, $tenantId, $recipe, $request->validated(), FinancialActor::id($request, $tenantId));

        return response()->json(['data' => $this->recipes->get($tenantId, $id)]);
    }

    public function status(Request $request, int $recipe): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $status = $request->validate(['status' => ['required', 'in:active,inactive']])['status'];
        $this->recipes->setStatus($request, $tenantId, $recipe, $status, FinancialActor::id($request, $tenantId));

        return response()->json(['data' => $this->recipes->get($tenantId, $recipe)]);
    }

    public function duplicate(Request $request, int $recipe): JsonResponse
    {
        $tenantId = TenantContext::id($request);
        $targetProductItemId = (int) $request->validate(['targetProductItemId' => ['required', 'integer']])['targetProductItemId'];
        $id = $this->recipes->duplicate($request, $tenantId, $recipe, $targetProductItemId, FinancialActor::id($request, $tenantId));

        return response()->json(['data' => $this->recipes->get($tenantId, $id)], 201);
    }
}
