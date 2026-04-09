# Install a2go CLI for Windows
# Usage: irm https://a2go.run/install.ps1 | iex
#        .\install.ps1 -Version dev-feat-foo

param(
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"

$Repo = "runpod-labs/a2go"
$Binary = "a2go"
$Asset = "a2go_windows_amd64.exe"

# Get release tag
# Uses GitHub's /releases/latest redirect instead of the API to avoid
# the 60-request/hour unauthenticated rate limit.
if ($Version) {
    $Tag = $Version
    Write-Host "Using specified version: $Tag"
} else {
    Write-Host "Finding latest release..."
    $request = [System.Net.HttpWebRequest]::Create("https://github.com/$Repo/releases/latest")
    $request.AllowAutoRedirect = $true
    $request.Method = "HEAD"
    $request.UserAgent = "a2go-installer"
    try {
        $response = $request.GetResponse()
        $Tag = ($response.ResponseUri.AbsolutePath -split '/')[-1]
        $response.Close()
    } catch {
        Write-Host "Could not determine latest release: $_"
        Write-Host "Check https://github.com/$Repo/releases"
        exit 1
    }
}

if (-not $Tag) {
    Write-Host "Could not find release."
    Write-Host "Check https://github.com/$Repo/releases"
    exit 1
}

$Url = "https://github.com/$Repo/releases/download/$Tag/$Asset"

Write-Host "Downloading $Binary $Tag for windows/amd64..."
Write-Host "  $Url"

# Install directory
$InstallDir = "$env:LOCALAPPDATA\a2go"
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

$DestPath = Join-Path $InstallDir "${Binary}.exe"

# Download
$TempFile = Join-Path $env:TEMP "a2go_download.exe"
try {
    Invoke-WebRequest -Uri $Url -OutFile $TempFile -UseBasicParsing
} catch {
    Write-Host "Download failed: $_"
    exit 1
}

# Verify SHA256 checksum
$ChecksumUrl = "$Url.sha256"
try {
    $ChecksumContent = (Invoke-WebRequest -Uri $ChecksumUrl -UseBasicParsing).Content
    $Expected = ($ChecksumContent -split '\s')[0].Trim().ToLower()
    $Actual = (Get-FileHash -Path $TempFile -Algorithm SHA256).Hash.ToLower()
    if ($Expected -ne $Actual) {
        Write-Host "ERROR: Checksum verification failed!"
        Write-Host "  Expected: $Expected"
        Write-Host "  Got:      $Actual"
        Remove-Item -Force $TempFile
        exit 1
    }
    Write-Host "  Checksum verified."
} catch {
    Write-Host "  WARNING: Checksum file not available, skipping verification."
}

Move-Item -Force $TempFile $DestPath
Write-Host "Installed to $DestPath"

# Add to PATH if not already there
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$InstallDir", "User")
    # Also update current session so the binary is usable immediately
    if ($env:PATH -notlike "*$InstallDir*") {
        $env:PATH = "$env:PATH;$InstallDir"
    }
    Write-Host ""
    Write-Host "Added $InstallDir to your PATH."
} else {
    Write-Host "$InstallDir is already in your PATH."
}

Write-Host ""
Write-Host "Next: a2go doctor"
Write-Host ""
