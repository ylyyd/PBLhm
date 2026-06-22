param(
    [Parameter(Mandatory=$true)]
    [string]$Sku,
    [Parameter(Mandatory=$true)]
    [string]$OutputFile
)

$rawfileDir = "E:\ollma\pp\entry\src\main\resources\rawfile"
$outputPath = Join-Path $rawfileDir $OutputFile

Write-Output "Fetching SKU $Sku..."

# Fetch JD product page
$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
try {
    $html = $wc.DownloadString("https://item.jd.com/$Sku.html")
} catch {
    Write-Output "  ERROR: Failed to fetch page - $_"
    exit 1
}

# Extract imageList from pageConfig
$match = [regex]::Match($html, "imageList:\s*\[(.*?)\]")
if (-not $match.Success) {
    Write-Output "  ERROR: Could not find imageList in page"
    exit 1
}

$imageList = $match.Groups[1].Value
$firstMatch = [regex]::Match($imageList, '"(jfs/t\d+/[^"]+\.(?:jpg|jpeg|png))"')
if (-not $firstMatch.Success) {
    Write-Output "  ERROR: Could not extract image path"
    exit 1
}

$jfsPath = $firstMatch.Groups[1].Value

# Try CDN hosts to download
$cdnHosts = @("img10.360buyimg.com", "img14.360buyimg.com", "img13.360buyimg.com", "img11.360buyimg.com")
$downloaded = $false

foreach ($hostName in $cdnHosts) {
    $imageUrl = "https://${hostName}/n1/${jfsPath}"
    Write-Output "  Trying $imageUrl ..."
    
    try {
        $wc2 = New-Object System.Net.WebClient
        $wc2.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        $wc2.DownloadFile($imageUrl, $outputPath)
        
        $size = (Get-Item $outputPath).Length
        if ($size -gt 2000) {
            $sizeKB = [math]::Round($size/1KB, 1)
            Write-Output "  ✅ Downloaded: $OutputFile ($sizeKB KB)"
            $downloaded = $true
            break
        } else {
            Write-Output "  ⚠ File too small ($size bytes), trying next host..."
            if (Test-Path $outputPath) { Remove-Item $outputPath }
        }
    } catch {
        Write-Output "  ⚠ Host failed, trying next..."
        if (Test-Path $outputPath) { Remove-Item $outputPath }
    }
}

if (-not $downloaded) {
    Write-Output "  ❌ Failed to download from all CDN hosts"
    exit 1
}
