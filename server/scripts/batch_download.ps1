# Batch download product images from JD.com CDN
# Format per line: sku,output_filename_1,output_filename_2

$rawfileDir = "E:\ollma\pp\entry\src\main\resources\rawfile"
$scriptPath = "E:\ollma\pp\server\scripts\download_jd_image.ps1"

$products = @(
    # Product 11: 海尔滚筒洗衣机
    @{sku="10068469442135"; file1="p_海尔滚筒洗衣机_1781524670404_1.png"; file2="p_海尔滚筒洗衣机_1781524670404_2.png"}
    # Product 12: 美的双开门冰箱
    @{sku="10174271009495"; file1="p_美的双开门冰箱_1781524670461_1.png"; file2="p_美的双开门冰箱_1781524670461_2.png"}
    # Product 13: 科沃斯扫地机器人
    @{sku="10209740977839"; file1="p_科沃斯扫地机器人_1781524670484_1.png"; file2="p_科沃斯扫地机器人_1781524670484_2.png"}
    # Product 14: 倍思65W充电器
    @{sku="10060582354034"; file1="p_倍思65W充电器_1781524670512_1.png"; file2="p_倍思65W充电器_1781524670512_2.png"}
    # Product 15: 绿联TypeC数据线
    @{sku="10067890439618"; file1="p_绿联TypeC数据线_1781524670548_1.png"; file2="p_绿联TypeC数据线_1781524670548_2.png"}
    # Product 16: 小米移动电源3
    @{sku="10059594544715"; file1="p_小米移动电源3_1781524670576_1.png"; file2="p_小米移动电源3_1781524670576_2.png"}
    # Product 17: 小米智能音箱
    @{sku="10181609245248"; file1="p_小米智能音箱_1781524670601_1.png"; file2="p_小米智能音箱_1781524670601_2.png"}
    # Product 18: 飞利浦电动牙刷
    @{sku="10068029441194"; file1="p_飞利浦电动牙刷_1781524670624_1.png"; file2="p_飞利浦电动牙刷_1781524670624_2.png"}
    # Product 19: 无印良品纯棉T恤
    @{sku="10211083301838"; file1="p_无印良品纯棉T恤_1781524670650_1.png"; file2="p_无印良品纯棉T恤_1781524670650_2.png"}
    # Product 20: 迪奥999口红
    @{sku="100132520918"; file1="p_迪奥999口红_1781524670669_1.png"; file2="p_迪奥999口红_1781524670669_2.png"}
)

$total = $products.Count
$success = 0
$fail = 0

Write-Output "Starting batch download of $total products..."

foreach ($p in $products) {
    Write-Output "`n=== Downloading SKU $($p.sku) ==="
    
    # Download image 1
    Write-Output "--- Image 1: $($p.file1) ---"
    & $scriptPath -Sku $p.sku -OutputFile $p.file1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Output "Image 1 OK"
        # Small delay
        Start-Sleep -Milliseconds 500
        
        # Download image 2
        Write-Output "--- Image 2: $($p.file2) ---"
        & $scriptPath -Sku $p.sku -OutputFile $p.file2
        
        if ($LASTEXITCODE -eq 0) {
            Write-Output "Image 2 OK"
            $success++
        } else {
            Write-Output "Image 2 FAILED"
            $fail++
        }
    } else {
        Write-Output "Image 1 FAILED"
        $fail++
    }
    
    # Delay between products
    Start-Sleep -Seconds 1
}

Write-Output "`n=== Batch Complete ==="
Write-Output "Success: $success / $total"
Write-Output "Failed: $fail / $total"
