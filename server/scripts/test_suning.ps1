param(
    [string]$ProductName = "茅台",
    [string]$OutputDir = "."
)

$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
$wc.Encoding = [System.Text.Encoding]::UTF8

# URL-encode the product name
$encodedName = [System.Uri]::EscapeDataString($ProductName)
$searchUrl = "https://search.suning.com/$encodedName/"

Write-Output "Searching Suning for: $ProductName"
Write-Output "URL: $searchUrl"

try {
    $html = $wc.DownloadString($searchUrl)
    $html = $html -replace '\s+', ' '
    Write-Output "Page size: $($html.Length) chars"
    
    # Find product image URLs
    $imagePattern = [regex]'(?:https?:)?//imgservice\.suning\.cn/uimg[^""\x27<>\s]+\.(?:jpg|jpeg|png)'
    $imageMatches = $imagePattern.Matches($html)
    Write-Output "Product images found: $($imageMatches.Count)"
    
    $uniqueUrls = @{}
    foreach ($m in $imageMatches) {
        $url = $m.Value
        if ($url -match '^//') { $url = "https:$url" }
        if (-not $uniqueUrls.ContainsKey($url)) {
            $uniqueUrls[$url] = $true
        }
    }
    
    $i = 0
    foreach ($url in $uniqueUrls.Keys) {
        $i++
        if ($i -le 10) {
            Write-Output ("  $i : $url")
        }
    }
    Write-Output "Unique images: $($uniqueUrls.Count)"
    
    # Also try to find product names and prices
    $namePattern = [regex]'"productName":"([^"]+)"'
    $nameMatches = $namePattern.Matches($html)
    Write-Output "Product names found: $($nameMatches.Count)"
    $i = 0
    foreach ($m in $nameMatches) {
        $i++
        if ($i -le 5) {
            Write-Output ("  $i : " + $m.Groups[1].Value)
        }
    }
    
    # Save search result HTML for analysis
    $outFile = Join-Path $OutputDir "suning_search_$ProductName.html"
    [System.IO.File]::WriteAllText($outFile, $html)
    Write-Output "HTML saved to: $outFile"
    
} catch {
    Write-Output "ERROR: $_"
}
