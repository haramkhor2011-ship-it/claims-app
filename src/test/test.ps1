<#
Combines all test source files under src/test into one text file.
Windows PowerShell 5.1 / PowerShell 7+ compatible.
#>

[CmdletBinding()]
param(
  [string]$Root = ".",
  [string]$OutFile = "Combined-Tests.txt",
  [string[]]$Extensions = @(".java", ".kt", ".groovy", ".scala"),
  [string[]]$SkipDirs = @("target","build","out",".git",".idea",".gradle","node_modules")
)

$ErrorActionPreference = "Stop"

# --- Normalize params in case caller passed empty strings or nulls ---
if ([string]::IsNullOrWhiteSpace($Root))    { $Root = "." }
if ([string]::IsNullOrWhiteSpace($OutFile)) { $OutFile = "Combined-Tests.txt" }

# --- Resolve the "root" directory WITHOUT Resolve-Path on non-existent paths ---
# Default: use the folder where THIS script lives (robust even if called from elsewhere).
# If -Root was explicitly provided and points to a real folder, use that instead.
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

try {
  $candidateRoot = if ($PSBoundParameters.ContainsKey('Root')) {
    # If a custom root was given, turn it into a full path relative to current location:
    if ([System.IO.Path]::IsPathRooted($Root)) { $Root } else { Join-Path -Path (Get-Location).Path -ChildPath $Root }
  } else {
    $scriptDir
  }

  # Normalize to an existing directory
  if (-not (Test-Path -LiteralPath $candidateRoot)) {
    throw "Root directory does not exist: '$candidateRoot'"
  }
  $rootPath = (Get-Item -LiteralPath $candidateRoot).FullName
}
catch {
  throw "Root path not found or invalid. Details: $($_.Exception.Message)"
}

# --- Build src/test path (string ops only) ---
$srcTest = Join-Path -Path $rootPath -ChildPath "src/test"
if (-not (Test-Path -LiteralPath $srcTest)) {
  throw "src/test not found at: $srcTest"
}

# --- Build skip regex (supports \ or /) ---
$skipPattern = ($SkipDirs | ForEach-Object { [regex]::Escape($_) }) -join "|"
$skipRegex = "(^|[\\/])($skipPattern)([\\/])"

# --- Collect files (no null paths) ---
$files = Get-ChildItem -LiteralPath $srcTest -Recurse -File |
  Where-Object {
    ($Extensions -contains $_.Extension.ToLower()) -and
    -not ($_.FullName -match $skipRegex)
  } |
  Sort-Object FullName

# --- Normalize and ensure output directory (DO NOT Resolve-Path on the file) ---
$desiredOutPath = if ([System.IO.Path]::IsPathRooted($OutFile)) {
  $OutFile
} else {
  Join-Path -Path (Get-Location).Path -ChildPath $OutFile
}
$outDir = Split-Path -Parent $desiredOutPath
if ([string]::IsNullOrWhiteSpace($outDir)) { $outDir = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $outDir)) { $null = New-Item -ItemType Directory -Force -Path $outDir }
$OutFile = Join-Path -Path $outDir -ChildPath (Split-Path -Leaf $desiredOutPath)

# --- Start fresh ---
"" | Out-File -LiteralPath $OutFile -Encoding UTF8

# --- Header ---
"# Combined test sources generated on $(Get-Date -Format o)" | Add-Content -LiteralPath $OutFile -Encoding UTF8
"Root: $rootPath" | Add-Content -LiteralPath $OutFile -Encoding UTF8
"Total files: $($files.Count)" | Add-Content -LiteralPath $OutFile -Encoding UTF8
"" | Add-Content -LiteralPath $OutFile -Encoding UTF8

# --- Robust relative path helper (no Get-Item/Resolve-Path required) ---
function Get-RelativePath([string]$BasePath, [string]$TargetPath) {
  if ([string]::IsNullOrWhiteSpace($BasePath))   { throw "Get-RelativePath: BasePath is null/empty." }
  if ([string]::IsNullOrWhiteSpace($TargetPath)) { throw "Get-RelativePath: TargetPath is null/empty." }
  $sep = [System.IO.Path]::DirectorySeparatorChar
  $baseFixed = if ($BasePath.EndsWith($sep)) { $BasePath } else { $BasePath + $sep }
  $baseUri   = [Uri]$baseFixed
  $targetUri = [Uri]$TargetPath
  ($baseUri.MakeRelativeUri($targetUri).ToString()) -replace '/', $sep
}

# --- Append contents ---
foreach ($f in $files) {
  $rel = Get-RelativePath -BasePath $rootPath -TargetPath $f.FullName

  @(
    "// ===== BEGIN: $rel ====="
    ""
  ) | Add-Content -LiteralPath $OutFile -Encoding UTF8

  try {
    Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | Add-Content -LiteralPath $OutFile -Encoding UTF8
  } catch {
    # Fallback for odd encodings
    Get-Content -LiteralPath $f.FullName -Raw | Add-Content -LiteralPath $OutFile
  }

  @(
    ""
    "// ===== END: $rel ====="
    ""
  ) | Add-Content -LiteralPath $OutFile -Encoding UTF8
}

Write-Host "Wrote $($files.Count) files to $OutFile"
