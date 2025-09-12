# Combines code from src/ into project_code.txt (adds pom.xml too).
# Skips: any path containing \target\ or \test\

$ErrorActionPreference = "Stop"

# --- Configure allowed extensions & root-level files ---
$includeExts  = @('.java','.xml','.xsd','.json','.yml','.yaml','.properties','.sql','.md','.txt')
$includeNames = @('pom.xml') # add more like 'Dockerfile','.editorconfig' if you want

# --- Anchor to script folder ---
$scriptDir = Split-Path -Parent $PSCommandPath
Set-Location $scriptDir

function Find-SrcFolder {
  param([string]$startDir)
  $dir = Get-Item -LiteralPath $startDir
  while ($null -ne $dir) {
    $candidate = Join-Path $dir.FullName "ingestion"
    if (Test-Path $candidate) { return (Get-Item $candidate) }
    $dir = $dir.Parent
  }
  return $null
}

$srcFolder = Find-SrcFolder -startDir $scriptDir
if (-not $srcFolder) { Write-Host "[ERROR] Could not locate a 'ingestion' folder above $scriptDir"; exit 1 }

$projectRoot = $srcFolder.Parent.FullName
$outFile     = Join-Path $projectRoot "project_code_ingestion.txt"

# Start fresh
Set-Content -Path $outFile -Value ("# Combined source export`n# Root: {0}`n" -f $projectRoot)

# Include selected root-level files (e.g., pom.xml)
foreach ($name in $includeNames) {
  $rootFile = Join-Path $projectRoot $name
  if (Test-Path $rootFile) {
    Add-Content -Path $outFile -Value ("`n// ===== File: {0} =====`n" -f $rootFile)
    Get-Content -LiteralPath $rootFile -Encoding UTF8 | Add-Content -Path $outFile
    Add-Content -Path $outFile -Value "`n"
  }
}

# Scan src/ for allowed extensions, skipping target/ and test/
$files = Get-ChildItem -Path $srcFolder.FullName -Recurse -File |
  Where-Object {
    $_.FullName -notmatch '\\target\\' -and $_.FullName -notmatch '\\test\\' -and
    ($includeExts -contains ([string]$_.Extension).ToLower())
  } |
  Sort-Object FullName

Write-Host ("[INFO] src: {0}" -f $srcFolder.FullName)
Write-Host ("[INFO] matched files: {0}" -f $files.Count)
Write-Host ("[INFO] writing: {0}" -f $outFile)

foreach ($f in $files) {
  Add-Content -Path $outFile -Value ("`n// ===== File: {0} =====`n" -f $f.FullName)
  Get-Content -LiteralPath $f.FullName -Encoding UTF8 | Add-Content -Path $outFile
  Add-Content -Path $outFile -Value "`n"
}

Write-Host "[OK] Done."