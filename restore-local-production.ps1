param(
    [string]$SourceDump = 'C:\Users\Batol\Downloads\cafe618-production-20260928T111155Z.dump'
)

$ErrorActionPreference = 'Stop'
$database = 'cafe_system_618'
$containerSafety = '/tmp/cafe618-local-before-restore.dump'
$repo = $PSScriptRoot
$sourceDir = Split-Path $SourceDump -Parent
$sourceFile = Split-Path $SourceDump -Leaf
$safetyDump = Join-Path (Split-Path $SourceDump -Parent) ("cafe618-local-before-restore-{0}.dump" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

function Assert-LastCommand([string]$Step) {
    if ($LASTEXITCODE -ne 0) { throw "$Step failed (exit code $LASTEXITCODE)." }
}

if (-not (Test-Path -LiteralPath $SourceDump -PathType Leaf)) {
    throw "Source dump not found: $SourceDump"
}

Push-Location $repo
try {
    $dockerHost = (docker context inspect --format '{{.Endpoints.docker.Host}}').Trim()
    Assert-LastCommand 'Inspect Docker context'
    if ($dockerHost -notlike 'npipe://*') { throw "Docker context is not local Windows Docker Desktop: $dockerHost" }
    docker info --format '{{.ServerVersion}}' | Out-Null
    Assert-LastCommand 'Docker connection'

    docker compose up -d postgres | Out-Null
    Assert-LastCommand 'Start local PostgreSQL container'
    $containerId = (docker compose ps -q postgres).Trim()
    Assert-LastCommand 'Find local PostgreSQL container'
    if (-not $containerId) { throw 'Local PostgreSQL container is not running. Start Docker Desktop and run docker compose up -d postgres.' }

    docker image inspect postgres:17 | Out-Null
    Assert-LastCommand 'Find PostgreSQL 17 restore client'
    docker run --rm -v "${sourceDir}:/dumps:ro" --entrypoint pg_restore postgres:17 -l "/dumps/$sourceFile" | Out-Null
    Assert-LastCommand 'Validate production dump archive'

    # Stop application writers before taking the local safety copy.
    docker compose stop backend super-admin-web | Out-Null
    Assert-LastCommand 'Stop local application'

    docker compose exec -T postgres pg_dump -U postgres -Fc -d $database -f $containerSafety
    Assert-LastCommand 'Back up current local database'
    docker cp "${containerId}:$containerSafety" $safetyDump
    Assert-LastCommand 'Copy local safety backup to Windows'
    if ((Get-Item -LiteralPath $safetyDump).Length -eq 0) { throw 'Local safety backup is empty.' }
    Write-Host "Local safety backup: $safetyDump"

    docker compose exec -T postgres dropdb -U postgres --force $database
    Assert-LastCommand 'Drop old local database'
    docker compose exec -T postgres createdb -U postgres -O postgres $database
    Assert-LastCommand 'Create replacement local database'
    docker compose exec -T postgres psql -U postgres -d $database -v ON_ERROR_STOP=1 -c 'CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public' | Out-Null
    Assert-LastCommand 'Create text search extension'
    $restoreCommand = "pg_restore -n public --no-owner --no-privileges -f /tmp/restore.sql /dumps/$sourceFile && sed -i '/^SET transaction_timeout = 0;/d' /tmp/restore.sql && psql -v ON_ERROR_STOP=1 -h postgres -U postgres -d $database -f /tmp/restore.sql >/dev/null"
    docker run --rm --network cafe-system_default -e PGPASSWORD=postgres -v "${sourceDir}:/dumps:ro" --entrypoint sh postgres:17 -c $restoreCommand
    Assert-LastCommand 'Restore production data'

    $tableCount = (docker compose exec -T postgres psql -U postgres -d $database -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE'").Trim()
    Assert-LastCommand 'Verify restored tables'
    if ([int]$tableCount -eq 0) { throw 'Restore completed but no public tables were found.' }
    $migrationCount = (docker compose exec -T postgres psql -U postgres -d $database -tAc 'SELECT count(*) FROM migrations').Trim()
    Assert-LastCommand 'Verify Laravel migrations'

    docker compose up -d backend super-admin-web | Out-Null
    Assert-LastCommand 'Restart local application'
    Write-Host "Restored $tableCount tables and $migrationCount migration records into $database."
    Write-Host "Local safety backup retained at: $safetyDump"
}
finally {
    Pop-Location
}
