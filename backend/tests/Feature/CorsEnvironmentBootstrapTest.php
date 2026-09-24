<?php

namespace Tests\Feature;

use Illuminate\Contracts\Console\Kernel;
use PHPUnit\Framework\Attributes\PreserveGlobalState;
use PHPUnit\Framework\Attributes\RunInSeparateProcess;
use PHPUnit\Framework\TestCase;

/**
 * Deliberately extends PHPUnit's own TestCase, not Tests\TestCase: Laravel's
 * testing TestCase boots the application in setUp(), which would make this
 * the SECOND boot in the process and reproduce the exact bug this test
 * exists to guard against (see CloudReadinessConfigurationTest for the
 * behavior-level CORS coverage, and the fix commit for the root cause:
 * Illuminate\Support\Env::$repository is a process-wide static, and its
 * ImmutableWriter silently re-applies .env once a key has already been
 * loaded once in that process).
 */
class CorsEnvironmentBootstrapTest extends TestCase
{
    #[RunInSeparateProcess]
    #[PreserveGlobalState(false)]
    public function test_cors_allowed_origins_env_is_honored_on_first_application_boot(): void
    {
        putenv('CORS_ALLOWED_ORIGINS=https://allowed.example.test,https://second.example.test');
        $_ENV['CORS_ALLOWED_ORIGINS'] = 'https://allowed.example.test,https://second.example.test';
        $_SERVER['CORS_ALLOWED_ORIGINS'] = 'https://allowed.example.test,https://second.example.test';

        $basePath = dirname(__DIR__, 2);

        require $basePath.'/vendor/autoload.php';

        $app = require $basePath.'/bootstrap/app.php';
        $app->make(Kernel::class)->bootstrap();

        $this->assertSame(
            ['https://allowed.example.test', 'https://second.example.test'],
            config('cors.allowed_origins'),
        );
    }
}
