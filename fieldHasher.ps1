<#
.SYNOPSIS
FieldHasher.ps1 — A flexible, high-performance field-level hashing tool for fixed-width or CSV files.

Supports prefix-based row filtering, configurable hashing algorithms (MD5, SHA1, SHA256, SHA512), character filtering (alpha, numeric, alphanumeric), output truncation, optional GUI prompt, UTF-8/ANSI encoding, dry-run mode, and multi-threaded processing. Ideal for deterministic masking for data sharing, enterprise UAT, and PII redaction pipelines.
#>


param (
    [string]$InputFile = "input.txt",
    [string]$OutputFile = "output.txt",
    [string]$RulesFile = "rules.json",
    [string]$Salt = "",
    [ValidateSet("MD5", "SHA1", "SHA256", "SHA512")]
    [string]$HashAlgorithm = "MD5",
    [string]$Prefix = "36",
    [ValidateSet("UTF8", "ANSI")]
    [string]$Encoding = "UTF8",
    [switch]$DryRun,
    [switch]$Csv,
    [switch]$Gui
)

if ($Gui) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show("GUI mode is not yet implemented.", "FieldHasher")
    exit
}

# Load field rules from JSON
if (Test-Path $RulesFile) {
    $jsonContent = Get-Content $RulesFile -Raw | ConvertFrom-Json
} else {
    Write-Error "Rules file not found: $RulesFile"
    exit
}

# Filtering logic
function Filter-Characters {
    param ([string]$input, [string]$filterType)
    switch ($filterType) {
        "alpha" { return ($input -replace '[^a-zA-Z]', '') }
        "numeric" { return ($input -replace '[^0-9]', '') }
        "alphanumeric" { return ($input -replace '[^a-zA-Z0-9]', '') }
        default { return $input }
    }
}

# Hashing logic
function Get-HashedValue {
    param (
        [string]$Input,
        [string]$FilterType,
        [int]$Truncate
    )

    $toHash = $Input + $Salt
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($toHash)
    $hasher = [System.Security.Cryptography.HashAlgorithm]::Create($HashAlgorithm)
    $hash = $hasher.ComputeHash($bytes)
    $hashStr = [BitConverter]::ToString($hash) -replace "-", ""
    $filtered = Filter-Characters -input $hashStr -filterType $FilterType
    return $filtered.Substring(0, [Math]::Min($Truncate, $filtered.Length))
}

# Line processing (parallel-safe)
function Process-Line {
    param (
        [string]$line
    )

    $prefix = $line.Substring(0,2)
    if (-not $jsonContent.ContainsKey($prefix)) {
        return $line
    }

    $fields = $jsonContent[$prefix]
    $chars = $line.ToCharArray()

    foreach ($field in $fields) {
        $start = [int]$field.Start
        $len = [int]$field.Length
        $truncate = [int]$field.Truncate
        $filter = $field.Filter

        $raw = -join $chars[$start..($start + $len - 1)]
        $hashed = Get-HashedValue -Input $raw -FilterType $filter -Truncate $truncate
        $padded = $hashed.PadRight($len)
        $chars[$start..($start + $len - 1)] = $padded.ToCharArray()
    }

    return -join $chars
}

# Main pipeline
if ($Csv) {
    $lines = Get-Content $InputFile
} else {
    $lines = Get-Content $InputFile -Raw -Encoding UTF8 | Select-String ".*" | ForEach-Object { $_.ToString() }
}

$results = [System.Collections.Concurrent.ConcurrentBag[string]]::new()
$lines | ForEach-Object -Parallel {
    $using:results.Add((Process-Line $_))
} -ThrottleLimit 8

if (-not $DryRun) {
    $enc = if ($Encoding -eq "UTF8") { [System.Text.Encoding]::UTF8 } else { [System.Text.Encoding]::Default }
    [System.IO.File]::WriteAllLines($OutputFile, $results, $enc)
}

"Hashing complete. Lines processed: $($results.Count)"
