<#
.SYNOPSIS
    Install REA (rea-agents) on Windows.

.DESCRIPTION
    Installs the REA CLI, and a private Node.js 24 runtime when the system Node
    is missing or older than what REA requires (22.23.4+ / 24.22.1+ / 26.12.1+).
    The system Node is never modified.

.PARAMETER NodeVersion
    Node.js release used when a private runtime is needed. Default 24.22.1.

.PARAMETER Mirror
    official  = https://nodejs.org  (default)
    npmmirror = https://npmmirror.com/mirrors/node  (mainland China)

.PARAMETER SkipSetup
    Install the CLI only. Skip the interactive `rea setup`.

.EXAMPLE
    irm https://raw.githubusercontent.com/USER/rea-setup/main/install.ps1 | iex

.EXAMPLE
    .\install.ps1 -Mirror npmmirror
#>
[CmdletBinding()]
param(
    [string]$NodeVersion = '24.22.1',
    [ValidateSet('official', 'npmmirror')]
    [string]$Mirror = 'official',
    [switch]$SkipSetup
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Step($Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok($Message) { Write-Host "    $Message" -ForegroundColor DarkGray }

function Test-NodeVersion([string]$Version) {
    if (-not $Version) { return $false }
    $clean = $Version.TrimStart('v').Split('-')[0]
    try { $p = [version]$clean } catch { return $false }
    switch ($p.Major) {
        22 { return ($p.Minor -gt 23) -or ($p.Minor -eq 23 -and $p.Build -ge 4) }
        24 { return ($p.Minor -gt 22) -or ($p.Minor -eq 22 -and $p.Build -ge 1) }
        26 { return ($p.Minor -gt 12) -or ($p.Minor -eq 12 -and $p.Build -ge 1) }
        default { return ($p.Major -gt 26) }
    }
}

function Find-Node {
    $cmd = Get-Command node -ErrorAction SilentlyContinue
    if (-not $cmd) { return $null }
    return $cmd.Source
}

Write-Step 'Checking Node.js'
$nodeExe = Find-Node
if ($nodeExe) {
    $current = (& $nodeExe --version).Trim()
    Write-Ok "found $current at $nodeExe"
} else {
    $current = $null
    Write-Ok 'node not found'
}

if (Test-NodeVersion $current) {
    $nodeDir = Split-Path -Parent $nodeExe
    $npmCmd = Join-Path $nodeDir 'npm.cmd'
    Write-Ok 'version is supported, system Node will be used'
} else {
    Write-Step "Preparing private Node.js $NodeVersion"
    $nodeDir = Join-Path $env:LOCALAPPDATA "Programs\node-v$NodeVersion"
    $cached = Join-Path $nodeDir 'node.exe'
    if ((Test-Path $cached) -and (Test-NodeVersion ((& $cached --version).Trim()))) {
        Write-Ok "reusing $nodeDir"
        $nodeExe = $cached
        $npmCmd = Join-Path $nodeDir 'npm.cmd'
    } else {
    $base = if ($Mirror -eq 'npmmirror') { "https://npmmirror.com/mirrors/node/v$NodeVersion" } else { "https://nodejs.org/dist/v$NodeVersion" }
    $zipName = "node-v$NodeVersion-win-x64.zip"
    $url = "$base/$zipName"
    $zipPath = Join-Path $env:TEMP $zipName

    Write-Ok "downloading $url"
    $web = New-Object System.Net.WebClient
    $web.Headers.Add('User-Agent', 'rea-setup')
    $web.DownloadFile($url, $zipPath)

    Write-Ok "extracting to $nodeDir"
    $staging = "$zipPath.extract"
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
    Expand-Archive -Path $zipPath -DestinationPath $staging -Force
    $inner = Join-Path $staging "node-v$NodeVersion-win-x64"
    if (Test-Path $nodeDir) { Remove-Item $nodeDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $nodeDir) | Out-Null
    Move-Item -Path $inner -Destination $nodeDir
    Remove-Item $staging, $zipPath -Recurse -Force -ErrorAction SilentlyContinue

    $nodeExe = Join-Path $nodeDir 'node.exe'
    $npmCmd = Join-Path $nodeDir 'npm.cmd'
    Write-Ok ((& $nodeExe --version).Trim() + ' ready')
    }

    # Give this private runtime its own global prefix so its shims use it, not the system Node.
    & $npmCmd config set prefix $nodeDir --location=global 2>&1 | Out-Null

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @($userPath -split ';' | Where-Object { $_ })
    if ($parts -notcontains $nodeDir) {
        [Environment]::SetEnvironmentVariable('Path', ((@($nodeDir) + $parts) -join ';'), 'User')
        Write-Ok 'added to user PATH (new terminals pick it up)'
    }
}

Write-Step 'Installing rea-agents'
$env:PATH = "$nodeDir;" + $env:PATH
$npmCache = Join-Path $nodeDir '.npm-cache'
New-Item -ItemType Directory -Force -Path $npmCache | Out-Null
$previousEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& $npmCmd install -g 'rea-agents@latest' --no-audit --no-fund --cache "$npmCache" 2>&1 | ForEach-Object { Write-Ok $_ }
$npmExit = $LASTEXITCODE
$ErrorActionPreference = $previousEap
if ($npmExit -ne 0) { throw "npm install failed with exit code $npmExit" }
$reaCmd = Join-Path $nodeDir 'rea.cmd'
if (-not (Test-Path $reaCmd)) {
    $reaCmd = (Get-Command rea.cmd -ErrorAction Stop).Source
}
$reaVersion = (& $reaCmd --version).Trim()
Write-Host "    rea $reaVersion" -ForegroundColor Green

Write-Step 'Health check'
& $reaCmd doctor --format=json 2>&1 | Out-File -Encoding utf8 (Join-Path $env:TEMP 'rea-doctor.json')
try {
    $doctor = Get-Content -Raw (Join-Path $env:TEMP 'rea-doctor.json') | ConvertFrom-Json
    Write-Ok ("skill: " + $doctor.identity.skill.state + " / version " + $doctor.identity.skill.installed_version)
} catch {
    Write-Ok 'doctor output was not JSON, run `rea doctor` manually'
}

if (-not $SkipSetup) {
    Write-Step 'Configuring your coding agent'
    Write-Host '    Pick the client(s) you use, confirm the plan, then restart the client.' -ForegroundColor DarkGray
    & $reaCmd setup
} else {
    Write-Host ""
    Write-Host 'Done. Next: run `rea.cmd setup` to connect your coding agent.' -ForegroundColor Green
}

Write-Host ""
Write-Host 'CLI   : ' -NoNewline; Write-Host $reaCmd
Write-Host 'Skill : ' -NoNewline; Write-Host (Join-Path $env:USERPROFILE '.agents\skills\reverse-engineer-anything')
Write-Host 'Docs  : https://morluto.github.io/rea/zh-CN/get-started/' -ForegroundColor DarkGray
