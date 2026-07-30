<?php

use App\Providers\AppServiceProvider;
use App\Providers\TestingDatabaseSafetyServiceProvider;

return [
    AppServiceProvider::class,
    TestingDatabaseSafetyServiceProvider::class,
];
