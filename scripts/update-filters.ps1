<#
.SYNOPSIS
    Tổng hợp danh sách domain cờ bạc/cá độ từ nhiều nguồn và tạo 3 file filter:
    AdGuard, AdAway (hosts) và uBlock Origin.

.DESCRIPTION
    Nguồn mặc định: blocklistproject, StevenBlack, HaGeZi Gambling (medium)
    và danh sách tuyển chọn trong data/curated-domains.txt.
    Chạy: powershell -ExecutionPolicy Bypass -File .\scripts\update-filters.ps1

.PARAMETER SkipDownload
    Dùng lại các file đã tải trong thư mục cache (không gọi mạng).

.PARAMETER CacheDir
    Thư mục chứa file nguồn đã tải.
#>
[CmdletBinding()]
param(
    [switch]$SkipDownload,
    [string]$CacheDir = (Join-Path $env:TEMP 'gamblock-src')
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$Root = Split-Path -Parent $PSScriptRoot
$DataDir    = Join-Path $Root 'data'
$FilterDir  = Join-Path $Root 'filters'
$ReportPath = Join-Path $DataDir 'stats.json'

New-Item -ItemType Directory -Force -Path $CacheDir, $DataDir, $FilterDir | Out-Null

# url = $null means a local curated file in data/
$Sources = @(
    @{ Name = 'blocklistproject-gambling.txt';       Format = 'hosts';  Url = 'https://raw.githubusercontent.com/blocklistproject/Lists/master/gambling.txt' }
    @{ Name = 'stevenblack-gambling-hosts.txt';      Format = 'hosts';  Url = 'https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/gambling-only/hosts'; Tier = 'lite' }
    @{ Name = 'hagezi-adblock-gambling-medium.txt';  Format = 'abp';    Url = 'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/gambling.medium.txt' }
    @{ Name = 'hagezi-domains-gambling-medium.txt';  Format = 'domain'; Url = 'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/gambling.medium-onlydomains.txt' }
    @{ Name = 'curated-domains.txt';                 Format = 'domain'; Url = $null; Local = (Join-Path $DataDir 'curated-domains.txt'); Tier = 'lite' }
)

# Bảo vệ các dịch vụ không phải cờ bạc nếu lọt vào nguồn nào đó.
$AllowList = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
@(
    'google.com','www.google.com','youtube.com','facebook.com','instagram.com',
    'twitter.com','x.com','reddit.com','github.com','microsoft.com','apple.com',
    'amazon.com','cloudflare.com','wikipedia.org','openai.com','telegram.org','t.me'
) | ForEach-Object { [void]$AllowList.Add($_) }

$ValidDomain = [regex]'^(?=.{4,253}$)([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$'
$Domains       = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$Stats         = [ordered]@{}
$SourceDomains = @{}
$script:CurrentSource = $null

function Add-Domain {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    $d = $Value.Trim().TrimEnd('.').ToLowerInvariant()
    if ($d -match '[\*\/\\\[\]\(\)\s]')  { return $false }
    if ($AllowList.Contains($d))          { return $false }
    if (-not $ValidDomain.IsMatch($d))    { return $false }
    $added = $Domains.Add($d)
    if ($added -and $null -ne $script:CurrentSource) { [void]$script:CurrentSource.Add($d) }
    return $added
}

function Read-SourceDomains {
    param([string]$Path, [string]$Format)
    $count = 0
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        $line = $line.Trim()
        if (-not $line -or $line.StartsWith('#') -or $line.StartsWith('!') -or $line.StartsWith('@@')) { continue }
        $value = $null
        switch ($Format) {
            'hosts' {
                if ($line -match '^(?:0\.0\.0\.0|127\.0\.0\.1|::1?)\s+(\S+)') { $value = $Matches[1] }
            }
            'abp' {
                if ($line -match '^\|\|([a-z0-9.-]+)(?:\^|$)') { $value = $Matches[1] }
            }
            default {
                $value = ($line -split '\s+')[0]
            }
        }
        if (Add-Domain $value) { $count++ }
    }
    return $count
}

Write-Host '==> Dang cap nhat nguon...' -ForegroundColor Cyan
foreach ($src in $Sources) {
    if ($src.Url) {
        $target = Join-Path $CacheDir $src.Name
        if (-not $SkipDownload) {
            Write-Host ("    tai {0}" -f $src.Name)
            try {
                Invoke-WebRequest -Uri $src.Url -OutFile $target -UseBasicParsing -TimeoutSec 180
            } catch {
                if (Test-Path $target) {
                    Write-Warning ("Khong tai duoc {0}, dung file cache: {1}" -f $src.Name, $_.Exception.Message)
                } else {
                    throw
                }
            }
        } elseif (-not (Test-Path $target)) {
            throw ("Thieu file cache: {0}" -f $target)
        }
        $src.Path = $target
    } else {
        $src.Path = $src.Local
    }
    $script:CurrentSource = [System.Collections.Generic.List[string]]::new()
    $added = Read-SourceDomains -Path $src.Path -Format $src.Format
    $SourceDomains[$src.Name] = $script:CurrentSource.ToArray()
    $script:CurrentSource = $null
    $Stats[$src.Name] = $added
    Write-Host ("    {0}: +{1} domain moi" -f $src.Name, $added)
}

$Sorted = [string[]]::new($Domains.Count)
$Domains.CopyTo($Sorted)
[System.Array]::Sort($Sorted, [System.StringComparer]::OrdinalIgnoreCase)
$Total = $Sorted.Count

# "Lite" tier: only high-confidence domains for browser extensions that have
# a hard cap on user-added rules (e.g. AdGuard Browser Extension on Chromium/MV3).
$LiteDomains = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($src in $Sources) {
    if ($src.Tier -eq 'lite' -and $SourceDomains.ContainsKey($src.Name)) {
        foreach ($d in $SourceDomains[$src.Name]) { [void]$LiteDomains.Add($d) }
    }
}
$LiteSorted = [string[]]::new($LiteDomains.Count)
$LiteDomains.CopyTo($LiteSorted)
[System.Array]::Sort($LiteSorted, [System.StringComparer]::OrdinalIgnoreCase)
$LiteTotal = $LiteSorted.Count

# Rules that only make sense in AdGuard / uBlock Origin (not in a hosts file).
$CosmeticPath = Join-Path $DataDir 'cosmetic-rules.txt'
$Cosmetic = @()
if (Test-Path $CosmeticPath) {
    $Cosmetic = @([System.IO.File]::ReadAllLines($CosmeticPath) | Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') })
}
$IpPath = Join-Path $DataDir 'blocked-ips.txt'
$IpRules = @()
if (Test-Path $IpPath) {
    foreach ($line in [System.IO.File]::ReadAllLines($IpPath)) {
        $ip = $line.Trim()
        if ($ip -and -not $ip.StartsWith('#') -and $ip -match '^\d{1,3}(\.\d{1,3}){3}$') { $IpRules += "||$ip^" }
    }
}
$ExtraCount = $Cosmetic.Count + $IpRules.Count

$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$Date      = (Get-Date).ToUniversalTime().ToString('yyyy.MMdd.HHmm')
$HumanDate = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm UTC')

function Write-Filter {
    param([string]$Path, [string[]]$Lines)
    [System.IO.File]::WriteAllLines($Path, $Lines, $Utf8NoBom)
    Write-Host ("    -> {0} ({1} dong)" -f (Split-Path $Path -Leaf), $Lines.Count)
}

$SourceNote = 'Sources: blocklistproject/Lists, StevenBlack/hosts, hagezi/dns-blocklists and curated list. See README.md.'

Write-Host '==> Tao file filter...' -ForegroundColor Cyan

$AdGuard = [System.Collections.Generic.List[string]]::new()
$AdGuard.Add('! Title: Gamblock - Gambling & Betting Blocklist (AdGuard)')
$AdGuard.Add('! Description: Chan cac trang ca cuoc, casino va ca do truc tuyen.')
$AdGuard.Add('! Homepage: https://github.com/konanguyen/gamblock')
$AdGuard.Add("! Version: $Date")
$AdGuard.Add("! Last modified: $HumanDate")
$AdGuard.Add('! Expires: 1 day')
$AdGuard.Add('! Syntax: Adblock Plus')
$AdGuard.Add("! Entries: $Total")
$AdGuard.Add("! Extra rules: $ExtraCount")
$AdGuard.Add("! $SourceNote")
$AdGuard.Add('!')
foreach ($d in $Sorted) { $AdGuard.Add("||$d^") }
foreach ($r in $IpRules) { $AdGuard.Add($r) }
if ($Cosmetic.Count) { $AdGuard.Add('! --- Cosmetic rules ---'); foreach ($r in $Cosmetic) { $AdGuard.Add($r) } }
Write-Filter -Path (Join-Path $FilterDir 'adguard-gambling.txt') -Lines $AdGuard.ToArray()

$UBlock = [System.Collections.Generic.List[string]]::new()
$UBlock.Add('! Title: Gamblock - Gambling & Betting Blocklist (uBlock Origin)')
$UBlock.Add('! Description: Chan cac trang ca cuoc, casino va ca do truc tuyen.')
$UBlock.Add('! Homepage: https://github.com/konanguyen/gamblock')
$UBlock.Add("! Version: $Date")
$UBlock.Add("! Last modified: $HumanDate")
$UBlock.Add('! Expires: 1 day')
$UBlock.Add('! Syntax: Adblock Plus')
$UBlock.Add("! Entries: $Total")
$UBlock.Add("! Extra rules: $ExtraCount")
$UBlock.Add("! $SourceNote")
$UBlock.Add('!')
foreach ($d in $Sorted) { $UBlock.Add("||$d^") }
foreach ($r in $IpRules) { $UBlock.Add($r) }
if ($Cosmetic.Count) { $UBlock.Add('! --- Cosmetic rules ---'); foreach ($r in $Cosmetic) { $UBlock.Add($r) } }
Write-Filter -Path (Join-Path $FilterDir 'ublock-origin-gambling.txt') -Lines $UBlock.ToArray()

$Hosts = [System.Collections.Generic.List[string]]::new()
$Hosts.Add('# Gamblock - Gambling & Betting hosts (AdAway)')
$Hosts.Add('# Chan cac trang ca cuoc, casino va ca do truc tuyen.')
$Hosts.Add('# Homepage: https://github.com/konanguyen/gamblock')
$Hosts.Add("# Version: $Date")
$Hosts.Add("# Last modified: $HumanDate")
$Hosts.Add("# Entries: $Total")
$Hosts.Add("# Cosmetic / IP rules only available in the AdGuard and uBlock Origin filters.")
$Hosts.Add("# $SourceNote")
$Hosts.Add('#')
foreach ($d in $Sorted) { $Hosts.Add("0.0.0.0 $d") }
Write-Filter -Path (Join-Path $FilterDir 'adaway-hosts.txt') -Lines $Hosts.ToArray()

# --- Lite filters for browser extensions with strict rule caps ---
$LiteNote = 'Lite tier: StevenBlack/hosts + curated list only. Use the full filters or DNS-level blocking for full coverage.'

$AdGuardLite = [System.Collections.Generic.List[string]]::new()
$AdGuardLite.Add('! Title: Gamblock - Gambling Blocklist LITE (AdGuard)')
$AdGuardLite.Add('! Description: Compact set for browser extensions with dynamic rule limits.')
$AdGuardLite.Add('! Homepage: https://github.com/konanguyen/gamblock')
$AdGuardLite.Add("! Version: $Date")
$AdGuardLite.Add("! Last modified: $HumanDate")
$AdGuardLite.Add('! Expires: 1 day')
$AdGuardLite.Add('! Syntax: Adblock Plus')
$AdGuardLite.Add("! Entries: $LiteTotal")
$AdGuardLite.Add("! Extra rules: $ExtraCount")
$AdGuardLite.Add("! $LiteNote")
$AdGuardLite.Add('!')
foreach ($d in $LiteSorted) { $AdGuardLite.Add("||$d^") }
foreach ($r in $IpRules) { $AdGuardLite.Add($r) }
if ($Cosmetic.Count) { $AdGuardLite.Add('! --- Cosmetic rules ---'); foreach ($r in $Cosmetic) { $AdGuardLite.Add($r) } }
Write-Filter -Path (Join-Path $FilterDir 'adguard-lite.txt') -Lines $AdGuardLite.ToArray()

$UBlockLite = [System.Collections.Generic.List[string]]::new()
$UBlockLite.Add('! Title: Gamblock - Gambling Blocklist LITE (uBlock Origin)')
$UBlockLite.Add('! Description: Compact set for browsers with low static rule limits.')
$UBlockLite.Add('! Homepage: https://github.com/konanguyen/gamblock')
$UBlockLite.Add("! Version: $Date")
$UBlockLite.Add("! Last modified: $HumanDate")
$UBlockLite.Add('! Expires: 1 day')
$UBlockLite.Add('! Syntax: Adblock Plus')
$UBlockLite.Add("! Entries: $LiteTotal")
$UBlockLite.Add("! Extra rules: $ExtraCount")
$UBlockLite.Add("! $LiteNote")
$UBlockLite.Add('!')
foreach ($d in $LiteSorted) { $UBlockLite.Add("||$d^") }
foreach ($r in $IpRules) { $UBlockLite.Add($r) }
if ($Cosmetic.Count) { $UBlockLite.Add('! --- Cosmetic rules ---'); foreach ($r in $Cosmetic) { $UBlockLite.Add($r) } }
Write-Filter -Path (Join-Path $FilterDir 'ublock-lite.txt') -Lines $UBlockLite.ToArray()

$HostsLite = [System.Collections.Generic.List[string]]::new()
$HostsLite.Add('# Gamblock - Gambling hosts LITE (AdAway)')
$HostsLite.Add('# Homepage: https://github.com/konanguyen/gamblock')
$HostsLite.Add("# Version: $Date")
$HostsLite.Add("# Entries: $LiteTotal")
$HostsLite.Add("# $LiteNote")
$HostsLite.Add('#')
foreach ($d in $LiteSorted) { $HostsLite.Add("0.0.0.0 $d") }
Write-Filter -Path (Join-Path $FilterDir 'adaway-lite-hosts.txt') -Lines $HostsLite.ToArray()

# Danh sach domain thuan (de doc / dung cho DNS khac)
[System.IO.File]::WriteAllLines((Join-Path $DataDir 'domains.txt'), $Sorted, $Utf8NoBom)

$StatsObject = [ordered]@{
    generated_at = $HumanDate
    total_domains = $Total
    lite_domains = $LiteTotal
    sources = $Stats
}
[System.IO.File]::WriteAllText($ReportPath, ($StatsObject | ConvertTo-Json -Depth 5), $Utf8NoBom)

Write-Host ("==> Xong! Tong cong {0} domain." -f $Total) -ForegroundColor Green
