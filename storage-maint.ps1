# Storage maintenance for this Windows machine.
# Tracked in chezmoi (chedot). Notes: "PowerShell Things/Storage Maintenance".
#
# Usage: storage-maint [-Drive C] [-Optimize] [-ComponentCleanup] [-ResetBase] [-DiskCleanup]
#   (no switches)      read-only: free space, drive type, Optimize-Volume -Analyze
#   -Optimize          Optimize-Volume: TRIM on an SSD, defrag on a hard disk
#   -ComponentCleanup  DISM /StartComponentCleanup (old Windows update files)
#   -ResetBase         with -ComponentCleanup: saves more, but installed
#                      updates can no longer be uninstalled
#   -DiskCleanup       cleanmgr /sagerun:1 (pick categories once: cleanmgr /sageset:1)
#
# Everything except the free-space report needs an admin PowerShell.
#
# Must stay compatible with Windows PowerShell 5.1, and ASCII-only: 5.1 reads
# a BOM-less script as Windows-1252.

param(
  [string]$Drive = 'C',
  [switch]$Optimize,
  [switch]$ComponentCleanup,
  [switch]$ResetBase,
  [switch]$DiskCleanup,
  [switch]$Help
)

if ($Help) {
  Get-Content $PSCommandPath | Select-Object -First 13 |
    ForEach-Object { $_ -replace '^# ?', '' }
  exit 0
}

$Drive = $Drive.TrimEnd(':', '\')
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)

function Show-FreeSpace {
  $v = Get-Volume -DriveLetter $Drive
  $free = [math]::Round($v.SizeRemaining / 1GB, 1)
  $size = [math]::Round($v.Size / 1GB, 1)
  $pct = [math]::Round(100 * $v.SizeRemaining / $v.Size)
  "${Drive}: $free GB free of $size GB ($pct%)"
}

function Show-MediaType {
  $part = Get-Partition -DriveLetter $Drive -ErrorAction SilentlyContinue
  if ($part) {
    $disk = Get-PhysicalDisk | Where-Object DeviceId -eq ([string]$part.DiskNumber)
    if ($disk) { "Disk: $($disk.FriendlyName), $($disk.MediaType), $($disk.BusType)" }
  }
}

"== Before"
Show-FreeSpace
Show-MediaType

$changing = $Optimize -or $ComponentCleanup -or $DiskCleanup
if (-not $IsAdmin) {
  if ($changing) {
    Write-Warning 'These switches need an admin PowerShell. Nothing was changed.'
    exit 1
  }
  'Not elevated: skipping Optimize-Volume -Analyze (needs admin).'
  exit 0
}

if (-not $changing) {
  "== Analyze"
  Optimize-Volume -DriveLetter $Drive -Analyze -Verbose
  exit 0
}

if ($Optimize) {
  "== Optimize-Volume"
  # No switch: Windows picks ReTrim for an SSD and Defrag for a hard disk
  Optimize-Volume -DriveLetter $Drive -Verbose
}

if ($ComponentCleanup) {
  "== DISM component cleanup"
  if ($ResetBase) {
    Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase
  } else {
    Dism.exe /Online /Cleanup-Image /StartComponentCleanup
  }
}

if ($DiskCleanup) {
  "== Disk Cleanup"
  Start-Process cleanmgr.exe -ArgumentList '/sagerun:1' -Wait
}

"== After"
Show-FreeSpace
