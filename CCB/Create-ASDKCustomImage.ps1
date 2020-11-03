###  About this script.....   coming soon.

$defaultLocalPath = "C:\AzureStackOnAzureVM"
$versionContainerName = "2005-40"
$region = 'WEST US 2'
$rg = 'ash_asdk_westus2_RG'
$version = $versionContainerName.split("-")[0]

New-Item -Path $defaultLocalPath -ItemType Directory -Force
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/development/scripts/ASDKHelperModule.psm1" -OutFile "$defaultLocalPath\ASDKHelperModule.psm1"
Import-Module "$defaultLocalPath\ASDKHelperModule.psm1" -Force
$asdkDownloadPath = "D:\"
$asdkExtractFolder = "Azure Stack Development Kit"
$d = Join-Path -Path $asdkDownloadPath -ChildPath $asdkExtractFolder
$vhdxFullPath = Join-Path -Path $d -ChildPath "cloudbuilder.vhdx"

$diskPath = "$d\asdk$version.vhdx"
$targetDiskPath = "$d\asdk$version.vhd"
Copy-Item -Path $vhdxFullPath -Destination $diskPath -Force
Convert-VHD -Path $diskPath -DestinationPath $targetDiskPath -VHDType Fixed
$vhd = "ASDK$version.vhd"

#  Create Storage and SAS Token
$saName = "asdk" + $version
New-AzResourceGroup -Name $rg -Location $region
New-AzStorageAccount -Location $region -ResourceGroupName $rg -SkuName Standard_LRS -Name $saName
Start-Sleep -s 90
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $rg -Name $saName).Value[0]
$storageContext = New-AzStorageContext -StorageAccountName $saName -StorageAccountKey $storageAccountKey
New-AzStorageContainer -Name vhd -Context $storageContext
$storagePolicyName = “vhd-policy”
New-AzStorageContainerStoredAccessPolicy -Container vhd -Policy $storagePolicyName -Permission rwdl -Context $storageContext
$sasToken = (New-AzStorageContainerSASToken -Name vhd -Policy $storagePolicyName -Context $storageContext).substring(1)

#  Uploade vhd to storage
$azcopyDestPath = "D:\azcopy.zip"
DownloadWithRetry -Uri https://aka.ms/downloadazcopy-v10-windows -DownloadLocation $azcopyDestPath
Unblock-File -Path $azcopyDestPath
Expand-Archive -Path $azcopyDestPath -DestinationPath D:\azcopy -Force
cd D:\azcopy\*

$env:AZCOPY_CRED_TYPE = "Anonymous";
./azcopy.exe copy "$d\$vhd" "https://$saName.blob.core.windows.net/vhd/asdk$version.vhd?$sasToken" --overwrite=prompt --follow-symlinks --recursive --from-to=LocalBlob --blob-type=PageBlob --put-md5;
$env:AZCOPY_CRED_TYPE = "";