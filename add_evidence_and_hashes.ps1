# Create folder (no error if already exists)
New-Item -Path $DestFolder -ItemType Directory -Force | Out-Null
Write-Log "Created/ensured folder: $DestFolder"

# Validate source
if (-not (Test-Path -Path $Source -PathType Leaf)) {
    throw "Source file not found: $Source"
}

# Copy file to destination
$DestFile = Join-Path -Path $DestFolder -ChildPath (Split-Path -Path $Source -Leaf)
Copy-Item -Path $Source -Destination $DestFolder -Force -ErrorAction Stop
Write-Log "Copied file to: $DestFile"

# Compute hashes for source and destination and verify
$sourceHash = Get-FileHash -Path $Source -Algorithm SHA256
$destHash   = Get-FileHash -Path $DestFile -Algorithm SHA256
$verified = ($sourceHash.Hash -eq $destHash.Hash)

# Write per-file .sha256.txt for the copied file
if ($CreatePerFileHash) {
    $shaFilePath = $DestFile + '.sha256.txt'
    # Format: <hash><two spaces><filename>
    $line = "{0}  {1}" -f $destHash.Hash, (Split-Path -Path $DestFile -Leaf)
    Set-Content -Path $shaFilePath -Value $line -Encoding ASCII
    Write-Log "Wrote per-file sha256: $shaFilePath"
}

# Create SHA256SUMS.txt for all files in folder (excluding *.sha256.txt and summary files)
if ($CreateSummary) {
    $summaryPath = Join-Path -Path $DestFolder -ChildPath 'SHA256SUMS.txt'
    $items = Get-ChildItem -Path $DestFolder -File | Where-Object { $_.Extension -ne '.sha256.txt' -and $_.Name -ne 'SHA256SUMS.txt' -and $_.Name -ne 'EVIDENCE_MANIFEST.txt' }
    $outLines = @()
    foreach ($it in $items) {
        $h = Get-FileHash -Path $it.FullName -Algorithm SHA256
        $outLines += ("{0}  {1}" -f $h.Hash, $it.Name)
    }
    if ($outLines.Count -gt 0) {
        Set-Content -Path $summaryPath -Value $outLines -Encoding ASCII
        Write-Log "Wrote summary SHA256SUMS: $summaryPath"
    } else {
        Write-Log "No files found to include in SHA256SUMS.txt"
    }
}

# Write an evidence manifest with metadata
$manifestPath = Join-Path -Path $DestFolder -ChildPath 'EVIDENCE_MANIFEST.txt'
$manifest = @()
$manifest += "Manifest generated: $(Get-Date -Format o)"
$manifest += "Source path: $Source"
$manifest += "Destination path: $DestFile"
$manifest += "File size (bytes): $((Get-Item $DestFile).Length)"
$manifest += "Source SHA256: $($sourceHash.Hash)"
$manifest += "Destination SHA256: $($destHash.Hash)"
$manifest += "Verification (source==destination): $verified"
$manifest += "Notes: Per-file .sha256.txt created: $CreatePerFileHash; Summary created: $CreateSummary"
Set-Content -Path $manifestPath -Value $manifest -Encoding UTF8
Write-Log "Wrote manifest: $manifestPath"

Write-Host "SUCCESS: File copied and hashes created."
Write-Host "Destination file: $DestFile"
Write-Host "SHA256 (destination): $($destHash.Hash)"
Write-Host "Verification of copy: $verified"
Write-Host "Per-file sha created: $($CreatePerFileHash.IsPresent)"
Write-Host "Summary sha list created: $($CreateSummary.IsPresent)"

exit 0
} catch { Write-Error "ERROR: ( _.Exception.Message)" exit 1 }
