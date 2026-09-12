<?php

namespace App\Http\Controllers\Api;

use App\Domain\Customer\CustomerAccess;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class CustomerCapabilityController extends Controller
{
    public function __construct(private readonly CustomerAccess $access) {}

    public function show(Request $request): JsonResponse
    {
        return response()->json([
            'data' => [
                'customer' => [
                    'manage' => $this->access->allows($request, 'customer.manage'),
                ],
            ],
        ]);
    }
}
