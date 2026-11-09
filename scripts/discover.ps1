<#
  discover.ps1 - READ-ONLY discovery of running systems, projects and databases.

  What it does NOT do: change, stop, start, delete or upload anything.
  What it writes: one text report on the Desktop (discovery-report.txt).
  Secrets: values in .env files are never written. Only the key names are listed,
  and for URL-like values only scheme://host is shown (no user, password or path).

  Usage (PowerShell):
    powershell -ExecutionPolicy Bypass -File .\discover.ps1
  Optional extra folders to scan:
    powershell -ExecutionPolicy Bypass -File .\discover.ps1 -ExtraRoots "D:\Work","C:\projects"
#>

param(
    [string[]]$ExtraRoots = @(),
    [int]$MaxDepth = 6
)

$ErrorActionPreference = "SilentlyContinue"
$report = Join-Path ([Environment]::GetFolderPath("Desktop")) "discovery-report.txt"
"" | Out-File $report -Encoding utf8

function Write-Section($title) {
    Add-Content $report ""
    Add-Content $report ("=" * 70)
    Add-Content $report $title
    Add-Content $report ("=" * 70)
}
function Write-Line($text) { Add-Content $report $text }

# ---------- 1. Machine ----------
Write-Section "1. MACHINE"
Write-Line ("Date:      " + (Get-Date))
Write-Line ("Computer:  " + $env:COMPUTERNAME)
Write-Line ("User:      " + $env:USERNAME)
Write-Line ("OS:        " + (Get-CimInstance Win32_OperatingSystem).Caption)
Write-Line ("WSL:       " + $(if (Get-Command wsl.exe) { "installed (see section 8)" } else { "not found" }))
Write-Line ("Docker:    " + $(if (Get-Command docker.exe) { "installed" } else { "not found" }))
Write-Line ("Git:       " + $(if (Get-Command git.exe) { (git --version) } else { "not found" }))
Write-Line ("Node:      " + $(if (Get-Command node.exe) { (node --version) } else { "not found" }))
Write-Line ("Python:    " + $(if (Get-Command python.exe) { (python --version 2>&1) } else { "not found" }))

# ---------- 2. Listening ports ----------
Write-Section "2. LISTENING PORTS (port -> process)"
Write-Line "Hints: 5432 Postgres, 3306 MySQL, 1433 SQL Server, 27017 MongoDB, 6379 Redis, 3000/5000/8000/8080 apps"
Get-NetTCPConnection -State Listen |
    Sort-Object LocalPort |
    ForEach-Object {
        $p = Get-Process -Id $_.OwningProcess
        "{0,-6} {1,-15} pid={2,-6} {3}  {4}" -f $_.LocalPort, $_.LocalAddress, $_.OwningProcess, $p.ProcessName, $p.Path
    } | Add-Content $report

# ---------- 3. Relevant processes ----------
Write-Section "3. APP / DB / TUNNEL PROCESSES"
$pattern = "node|python|java|dotnet|php|ruby|postgres|mysql|mariadb|mongo|redis|sqlservr|ngrok|cloudflared|lt|localtunnel|docker|nginx|apache|httpd|caddy"
Get-CimInstance Win32_Process |
    Where-Object { $_.Name -match $pattern } |
    ForEach-Object {
        "pid={0} {1}`n    exe: {2}`n    cmd: {3}" -f $_.ProcessId, $_.Name, $_.ExecutablePath, $_.CommandLine
    } | Add-Content $report

# ---------- 4. Windows services ----------
Write-Section "4. DATABASE / WEB WINDOWS SERVICES"
Get-Service |
    Where-Object { $_.Name -match "postgres|mysql|maria|mongo|redis|sql|nginx|apache|w3svc|ngrok|cloudflared" -or $_.DisplayName -match "postgres|mysql|maria|mongo|redis|sql server|nginx|apache|ngrok|cloudflared" } |
    ForEach-Object { "{0,-10} {1}  ({2})" -f $_.Status, $_.DisplayName, $_.Name } |
    Add-Content $report

# ---------- 5. Docker ----------
Write-Section "5. DOCKER"
if (Get-Command docker.exe) {
    Write-Line "-- containers --"
    docker ps -a --format "{{.Names}} | {{.Image}} | {{.Status}} | {{.Ports}}" 2>&1 | Add-Content $report
    Write-Line "-- volumes --"
    docker volume ls 2>&1 | Add-Content $report
} else { Write-Line "Docker not installed." }

# ---------- 6. Projects, DB files, env files ----------
Write-Section "6. PROJECT FOLDERS AND DATABASE FILES"
$skip = "node_modules|\\\.git$|\\AppData|\\\.cache|\\venv$|\\\.venv$|\\site-packages|\\Windows|\\Program Files|\\\$Recycle|\\\.npm|\\\.nuget"
$roots = @($HOME) + $ExtraRoots + @("C:\projects","C:\dev","C:\www","C:\inetpub","C:\xampp","D:\") |
    Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

$projectMarkers = "package.json","requirements.txt","pyproject.toml","docker-compose.yml","docker-compose.yaml","composer.json","pom.xml","Gemfile","manage.py","schema.prisma"
$dbExt = ".sqlite",".sqlite3",".db",".mdb",".bak",".sql",".dump"
$envFiles = New-Object System.Collections.Generic.List[string]

function Scan($dir, $depth) {
    if ($depth -gt $MaxDepth) { return }
    foreach ($item in (Get-ChildItem -LiteralPath $dir -Force)) {
        if ($item.FullName -match $skip) { continue }
        if ($item.PSIsContainer) {
            Scan $item.FullName ($depth + 1)
        } else {
            if ($projectMarkers -contains $item.Name) { Write-Line ("PROJECT  " + $item.FullName) }
            if ($dbExt -contains $item.Extension.ToLower()) {
                Write-Line ("DBFILE   {0}  ({1:N0} KB, modified {2})" -f $item.FullName, ($item.Length / 1KB), $item.LastWriteTime)
            }
            if ($item.Name -like ".env*" -or $item.Name -eq "appsettings.json" -or $item.Name -eq "config.json") {
                $envFiles.Add($item.FullName)
            }
        }
    }
}
foreach ($r in $roots) { Write-Line "[scanning $r]"; Scan $r 0 }

# ---------- 7. Env/config keys (values hidden) ----------
Write-Section "7. ENV / CONFIG FILES (key names only, values masked)"
foreach ($f in $envFiles) {
    Write-Line ""
    Write-Line "FILE: $f"
    foreach ($line in (Get-Content -LiteralPath $f -TotalCount 200)) {
        if ($line -match '^\s*#') { continue }
        if ($line -match '^\s*([A-Za-z0-9_\.]+)\s*=\s*(.*)$') {
            $key = $Matches[1]; $val = $Matches[2].Trim('"', "'")
            if ($val -match '^([a-zA-Z][a-zA-Z0-9+\-.]*)://(?:[^@/]*@)?([^/:?\s]+)') {
                Write-Line ("  {0} = {1}://{2}  (host only)" -f $key, $Matches[1], $Matches[2])
            } else {
                Write-Line ("  {0} = ***" -f $key)
            }
        }
    }
}

# ---------- 8. WSL ----------
Write-Section "8. WSL"
if (Get-Command wsl.exe) {
    wsl.exe -l -v 2>&1 | Add-Content $report
    Write-Line "If a distro is listed, the project may live inside it. Ask Asmaa for the Linux version of this script."
} else { Write-Line "WSL not installed." }

# ---------- 9. Tunnel clues ----------
Write-Section "9. TUNNEL CLUES (ngrok / cloudflared / localtunnel)"
foreach ($p in @("$env:USERPROFILE\.ngrok2","$env:LOCALAPPDATA\ngrok","$env:USERPROFILE\.cloudflared")) {
    if (Test-Path $p) { Write-Line ("Found config folder: " + $p) }
}
Get-Process | Where-Object { $_.ProcessName -match "ngrok|cloudflared" } |
    ForEach-Object { Write-Line ("Running: " + $_.ProcessName + "  " + $_.Path) }

Write-Line ""
Write-Line "DONE. Review the report, remove anything you don't want to share, then send it."
Write-Host "Report saved to: $report"
