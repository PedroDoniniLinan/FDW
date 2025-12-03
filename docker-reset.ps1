# Docker Compose Reset Script
# Stops containers, removes volumes, and starts fresh

Write-Host "Stopping and removing containers, networks, and volumes..." -ForegroundColor Yellow
docker-compose down -v

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: docker-compose down failed" -ForegroundColor Red
    exit 1
}

Write-Host "Starting containers..." -ForegroundColor Green
docker-compose up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: docker-compose up failed" -ForegroundColor Red
    exit 1
}

Write-Host "Done! Containers are running." -ForegroundColor Green
docker-compose ps

Write-Host "Waiting for PostgreSQL to be ready..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0
$ready = $false

while ($attempt -lt $maxAttempts -and -not $ready) {
    $attempt++
    $result = docker-compose exec -T db pg_isready -U donini 2>&1
    if ($LASTEXITCODE -eq 0) {
        $ready = $true
        Write-Host "PostgreSQL is ready!" -ForegroundColor Green
    } else {
        Start-Sleep -Seconds 1
        Write-Host "." -NoNewline -ForegroundColor Gray
    }
}

if (-not $ready) {
    Write-Host "`nWarning: PostgreSQL did not become ready in time" -ForegroundColor Yellow
} else {
    Write-Host "Running SQL command..." -ForegroundColor Green
    docker-compose exec db psql -U donini -d prod -c "\dn"
}