# fill-docx-impl.ps1
# NO param() block intentionally — when called via `powershell -File`, all args
# land in $args as plain strings, bypassing PowerShell parameter binding.
# This avoids the `-o` ambiguity with -OutVariable/-OutBuffer in the scoop shim.

$originalPwd = (Get-Location).Path
$resolvedArgs = @()
$hasOutput    = $false
$nextIsOutput = $false

foreach ($tok in $args) {
  if ($nextIsOutput) {
    if ([System.IO.Path]::IsPathRooted($tok)) {
      $resolvedArgs += $tok
    } else {
      $resolvedArgs += (Join-Path $originalPwd $tok)
    }
    $nextIsOutput = $false
    $hasOutput    = $true
  } elseif ($tok -eq '-o') {
    $resolvedArgs += '-o'
    $nextIsOutput  = $true
  } elseif (Test-Path $tok) {
    $resolvedArgs += (Resolve-Path $tok).Path
  } else {
    $resolvedArgs += $tok
  }
}

if (-not $hasOutput) {
  $resolvedArgs += '-o'
  $resolvedArgs += (Join-Path $originalPwd 'output.docx')
}

# $PSScriptRoot = libexec (directory of this script)
Push-Location $PSScriptRoot
try {
  & bb 'fill_docx.bb' @resolvedArgs
} finally {
  Pop-Location
}
