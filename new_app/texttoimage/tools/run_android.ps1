# Launches the Flutter app on a connected Android device.
# Usage:
#   & .\tools\run_android.ps1
# Optional:
#   & .\tools\run_android.ps1 -DeviceId <id>

param(
  [string]$DeviceId = ""
)

$ErrorActionPreference = "Stop"

# Ensure we run from the Flutter project root.
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

if ([string]::IsNullOrWhiteSpace($DeviceId)) {
  flutter run
} else {
  flutter run -d $DeviceId
}
