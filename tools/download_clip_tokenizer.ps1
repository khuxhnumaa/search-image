# Downloads OpenAI CLIP BPE tokenizer files into Flutter assets.
# Resulting app can tokenize text fully offline.
#
# Usage (PowerShell):
#   Set-Location <projectRoot>
#   .\tools\download_clip_tokenizer.ps1

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$tokenizerDir = Join-Path $projectRoot "assets\tokenizer"

New-Item -ItemType Directory -Force -Path $tokenizerDir | Out-Null

# Remove old placeholder if present
$placeholder = Join-Path $tokenizerDir "PLACE_TOKENIZER_FILES_HERE.txt"
if (Test-Path $placeholder) {
  Remove-Item $placeholder -Force
}

$vocabUrl = "https://huggingface.co/openai/clip-vit-base-patch32/resolve/main/vocab.json"
$mergesUrl = "https://huggingface.co/openai/clip-vit-base-patch32/resolve/main/merges.txt"

$vocabOut = Join-Path $tokenizerDir "vocab.json"
$mergesOut = Join-Path $tokenizerDir "merges.txt"

Write-Host "Downloading vocab.json..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $vocabUrl -OutFile $vocabOut

Write-Host "Downloading merges.txt..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $mergesUrl -OutFile $mergesOut

Write-Host "Done. Files:" -ForegroundColor Green
Get-ChildItem $tokenizerDir | Select-Object Name,Length | Format-Table -AutoSize
