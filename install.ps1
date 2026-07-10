<#
.SYNOPSIS
    Idempotent setup script for PWSH (PowerShell Core) Profile & Dependencies.
#>

# Enforce PWSH (Core) Environment
if ($PSVersionTable.PSVersion.Major -lt 6) {
    Write-Error "Wrong Shell: You are running Windows PowerShell (v5.1). Please launch 'pwsh' (v7+) and run this script again."
    exit
}

# Elevate to Admin (Using pwsh.exe)
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Elevating to Administrator (pwsh)..." -ForegroundColor Yellow
    # Note the use of pwsh.exe here instead of powershell.exe
    Start-Process pwsh.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

$ErrorActionPreference = "Stop"

# --- Helper Functions ---

function Write-Header ($text) {
    Write-Host "`n=== $text ===" -ForegroundColor Cyan
}

function Install-WingetPackage {
    param([string]$Id, [string]$Name)
    if (Get-Command $Name -ErrorAction SilentlyContinue) {
        Write-Host "$Name is already installed." -ForegroundColor DarkGray
    } else {
        Write-Host "- Installing $Name ($Id)..." -ForegroundColor Yellow
        winget install --id $Id -e --source winget --accept-package-agreements --accept-source-agreements
    }
}

function Install-PSMod {
    param([string]$Name)
    if (Get-Module -ListAvailable -Name $Name) {
        Write-Host "Module $Name is already installed." -ForegroundColor DarkGray
    } else {
        Write-Host "⬇ Installing Module $Name..." -ForegroundColor Yellow
        Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
    }
}

# --- Install External CLI Tools (Winget) ---
Write-Header "Checking External Dependencies"

# Use Winget as packages are better maintained
# Standardize on Winget for cleanliness. 
Install-WingetPackage -Id "Git.Git"             -Name "git"
Install-WingetPackage -Id "7zip.7zip"           -Name "7z"
Install-WingetPackage -Id "vim.vim"             -Name "vim"
Install-WingetPackage -Id "gerardog.gsudo"      -Name "gsudo"
Install-WingetPackage -Id "ajeetdsouza.zoxide"  -Name "zoxide"
Install-WingetPackage -Id "Starship.Starship"   -Name "starship"
Install-WingetPackage -Id "junegunn.fzf"        -Name "fzf" # Required for PSFzf

# winget install for bat is broken. Manually use choco
# Install-WingetPackage -Id "sharkdp.bat"         -Name "bat"
if (-not (Get-Command bat -ErrorAction SilentlyContinue)){
    Write-Host "- Please install bat with chocolatey" -ForegroundColor Yellow
}

# --- Install PowerShell Modules ---
Write-Header "Checking PowerShell Modules"

# PSReadLine is built-in usually, but we force update to ensure prediction support
Install-PSMod -Name "PSReadLine"
Install-PSMod -Name "posh-git"
Install-PSMod -Name "PSFzf"
Install-PSMod -Name "Terminal-Icons" # Companion for Starship

# --- Register local bin in PATH ---
$localBin = "$HOME\.local\bin" # Uses $HOME to be dynamically generic for any user

if (-not (Test-Path $localBin)) {
    New-Item -ItemType Directory -Path $localBin -Force | Out-Null
}

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -split ';' -notcontains $localBin) {
    $newPath = if ([string]::IsNullOrEmpty($userPath)) { $localBin } else { "$userPath;$localBin" }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:Path += ";$localBin" # Updates current installer session immediately
}

# --- Deploy Profile ---
Write-Header "Deploying Dotfiles"

$ProfilePath = $PROFILE
$SourcePath = "$PSScriptRoot\Microsoft.PowerShell_profile.ps1"

# Ensure the directory exists
$ProfileDir = Split-Path $ProfilePath
if (-not (Test-Path $ProfileDir)) {
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
}

# Backup existing profile if it's different
if (Test-Path $ProfilePath) {
    $CurrentHash = Get-FileHash $ProfilePath
    $NewHash = Get-FileHash $SourcePath
    
    if ($CurrentHash.Hash -ne $NewHash.Hash) {
        $BackupName = "$ProfilePath.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Write-Host "Backing up existing profile to $BackupName" -ForegroundColor Yellow
        Move-Item $ProfilePath $BackupName -Force
        
        Write-Host "Copying new profile..." -ForegroundColor Green
        Copy-Item $SourcePath $ProfilePath -Force
    } else {
        Write-Host "Profile is already up to date." -ForegroundColor DarkGray
    }
} else {
    Write-Host "Installing new profile..." -ForegroundColor Green
    Copy-Item $SourcePath $ProfilePath -Force
}

Write-Header "Setup Complete"
Write-Host "Everything looks good! Restart your terminal to see changes." -ForegroundColor Green

# Nerd Font Warning
Write-Host "NOTE: Ensure you are using a 'Nerd Font' (e.g., CaskaydiaCove NF) in your terminal settings for Starship icons to render." -ForegroundColor Magenta
