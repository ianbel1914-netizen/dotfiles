# bootstrap.ps1 — Set up a new Windows dev machine
# Run as Administrator: Set-ExecutionPolicy Bypass -Scope Process -Force; .\bootstrap.ps1

#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "`n=== Dev Machine Bootstrap ===" -ForegroundColor Cyan
Write-Host "Setting up core tools and configuration...`n"

# --- 1. Install core tools via winget ---
$packages = @(
    "Git.Git",
    "Microsoft.VisualStudioCode",
    "Tailscale.Tailscale",
    "GitHub.cli",
    "Docker.DockerDesktop",
    "OpenJS.NodeJS.LTS",
    "Python.Python.3.12"
)

foreach ($pkg in $packages) {
    Write-Host "Installing $pkg..." -ForegroundColor Yellow
    winget install $pkg --accept-package-agreements --accept-source-agreements --silent
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
        Write-Host "  Warning: $pkg may have failed (exit $LASTEXITCODE), continuing..." -ForegroundColor Red
    } else {
        Write-Host "  OK" -ForegroundColor Green
    }
}

# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# --- 2. Configure Git ---
Write-Host "`nConfiguring Git..." -ForegroundColor Yellow
git config --global user.name "Ian"
git config --global user.email "ianbel1914@gmail.com"
git config --global init.defaultBranch main
Write-Host "  OK" -ForegroundColor Green

# --- 3. Authenticate GitHub CLI ---
Write-Host "`nAuthenticating GitHub CLI..." -ForegroundColor Yellow
$ghStatus = gh auth status 2>&1
if ($ghStatus -match "Logged in") {
    Write-Host "  Already authenticated" -ForegroundColor Green
} else {
    Write-Host "  Opening browser for GitHub login..."
    gh auth login --web --git-protocol ssh
    gh auth refresh -h github.com -s admin:public_key
}

# --- 4. SSH Key ---
Write-Host "`nSetting up SSH key..." -ForegroundColor Yellow
if (-not (Test-Path "$env:USERPROFILE\.ssh\id_ed25519")) {
    ssh-keygen -t ed25519 -C "ianbel1914@gmail.com" -f "$env:USERPROFILE\.ssh\id_ed25519" -N '""'
    gh ssh-key add "$env:USERPROFILE\.ssh\id_ed25519.pub" --title "$env:COMPUTERNAME"
    Write-Host "  SSH key created and added to GitHub" -ForegroundColor Green
} else {
    Write-Host "  SSH key already exists" -ForegroundColor Green
}

# Add GitHub to known_hosts
ssh-keyscan github.com >> "$env:USERPROFILE\.ssh\known_hosts" 2>$null

# --- 5. Clone all GitHub repos ---
Write-Host "`nCloning all GitHub repos into ~/repos..." -ForegroundColor Yellow
$reposDir = "$env:USERPROFILE\repos"
if (-not (Test-Path $reposDir)) { New-Item -ItemType Directory -Path $reposDir | Out-Null }

$repos = gh repo list --json name --jq ".[].name" 2>$null
foreach ($repo in $repos) {
    $repoPath = Join-Path $reposDir $repo
    if (-not (Test-Path $repoPath)) {
        Write-Host "  Cloning $repo..."
        gh repo clone $repo $repoPath 2>$null
    } else {
        Write-Host "  $repo already exists, skipping"
    }
}
Write-Host "  OK" -ForegroundColor Green

# --- 6. VS Code Tunnel ---
Write-Host "`nSetting up VS Code Tunnel as 'main-dev'..." -ForegroundColor Yellow
$tunnelName = "main-dev"
Write-Host "  Run manually if needed: code tunnel --name $tunnelName"
Write-Host "  Then install as service: code tunnel service install --name $tunnelName"

# --- 7. Print next steps ---
Write-Host "`n=== Bootstrap Complete ===" -ForegroundColor Green
Write-Host "`nNext steps (manual):" -ForegroundColor Cyan
Write-Host "  1. Open Tailscale and sign in to your tailnet"
Write-Host "  2. Enable VS Code Settings Sync (sign in with GitHub)"
Write-Host "  3. Copy .env files from secure backup to each project"
Write-Host "  4. Start Docker Desktop and verify it's running"
Write-Host "  5. Set up VS Code tunnel: code tunnel service install --name main-dev"
Write-Host ""
