param(
    [string]$RawfileDir = "E:\ollma\pp\entry\src\main\resources\rawfile",
    [string]$LogFile = "suning_download_log.txt"
)

$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
$wc.Encoding = [System.Text.Encoding]::UTF8

function Find-SuningPage {
    param([string]$ProductName)
    
    $encodedName = [System.Uri]::EscapeDataString($ProductName)
    $searchUrl = "https://search.suning.com/$encodedName/"
    
    try {
        $html = $wc.DownloadString($searchUrl)
        
        # Extract product URLs from search results
        $urlPattern = [regex]'"productUrl":"([^"]+)"'
        $matches = $urlPattern.Matches($html)
        
        $firstUrl = $null
        foreach ($m in $matches) {
            $url = $m.Groups[1].Value
            if ($url -match 'product\.suning\.com') {
                $firstUrl = $url
                break
            }
        }
        return $firstUrl
    } catch {
        return $null
    }
}

function Get-ImagesFromSuningPage {
    param([string]$PageUrl)
    
    try {
        $html = $wc.DownloadString($PageUrl)
        
        # Extract src2 image URLs (Suning uses lazy loading with src2 attribute)
        $images = @()
        $pattern = [regex]'src2="([^"]+\.(?:jpg|jpeg|png))"'
        $matches = $pattern.Matches($html)
        
        foreach ($m in $matches) {
            $url = $m.Groups[1].Value
            if ($url -match '^//') {
                $url = "https:$url"
            }
            if (-not ($images -contains $url)) {
                $images += $url
            }
        }
        
        # If no src2 found, try direct img src
        if ($images.Count -eq 0) {
            $pattern2 = [regex]'(?:https?:)?//uimgproxy\.suning\.cn/uimg[^""\x27<>\s]+\.(?:jpg|jpeg|png)'
            $matches2 = $pattern2.Matches($html)
            foreach ($m in $matches2) {
                $url = $m.Value
                if ($url -match '^//') {
                    $url = "https:$url"
                }
                if (-not ($images -contains $url)) {
                    $images += $url
                }
            }
        }
        
        return $images
    } catch {
        return @()
    }
}

# Product list: product name to Suning URL mapping
# Test a few products first
$testProducts = @(
    @{Name="科沃斯扫地机器人"; Url="https://product.suning.com/0000000000/12358438244.html"},
    @{Name="迪奥999口红"; Url="https://www.suning.com/item/0070211365/12360704105.html"}
)

Write-Output "Testing Suning image extraction..."
foreach ($p in $testProducts) {
    Write-Output "`n=== $($p.Name) ==="
    Write-Output "URL: $($p.Url)"
    
    $images = Get-ImagesFromSuningPage -PageUrl $p.Url
    Write-Output "Found $($images.Count) images"
    
    $i = 0
    foreach ($img in $images) {
        $i++
        if ($i -le 5) {
            Write-Output ("  Image $i : $img")
            
            # Try downloading first image
            $ext = [System.IO.Path]::GetExtension($img.Split('?')[0])
            $outFile = Join-Path $RawfileDir "suning_test_$($p.Name)_${i}${ext}"
            try {
                $dl = New-Object System.Net.WebClient
                $dl.Headers.Add("User-Agent", "Mozilla/5.0")
                $dl.Headers.Add("Referer", "https://product.suning.com/")
                $dl.DownloadFile($img, $outFile)
                $size = (Get-Item $outFile).Length
                Write-Output "    Downloaded: $size bytes - $(if($size -ge 20000){'GOOD'}else{'TOO SMALL'})"
            } catch {
                Write-Output "    Download failed: $_"
            }
        }
    }
}
