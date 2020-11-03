#Create Storage account and SAS token
#Create VM E8 Run following script to download, extract, convert and upload vhd file to SA

# Install-WindowsFeature Hyper-V -IncludeManagementTools -Restart

$defaultLocalPath = "C:\AzureStackOnAzureVM"
$versionContainerName = "2005-40"
$region = 'WEST US 2'
$rg = 'ash_asdk_westus2_RG'
$version = $versionContainerName.split("-")[0]

New-Item -Path $defaultLocalPath -ItemType Directory
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/development/scripts/ASDKHelperModule.psm1" -OutFile "$defaultLocalPath\ASDKHelperModule.psm1"
Import-Module "$defaultLocalPath\ASDKHelperModule.psm1" -Force
$asdkDownloadPath = "D:\"
$asdkExtractFolder = "Azure Stack Development Kit"
$d = Join-Path -Path $asdkDownloadPath -ChildPath $asdkExtractFolder
$vhdxFullPath = Join-Path -Path $d -ChildPath "cloudbuilder.vhdx"

# Following are commented out because it is for downloading and extracting files.  Which right now doesn't seem to work.  

# $asdkFiles = ASDKDownloader -Destination $asdkDownloadPath -Version $versionContainerName
# $f = Join-Path -Path $asdkDownloadPath -ChildPath $asdkFiles[0].Split("/")[-1]
# ExtractASDK -File $f -Destination $d

$diskPath = "$d\asdk$version.vhdx"
$targetDiskPath = "$d\asdk$version.vhd"
Copy-Item -Path $vhdxFullPath -Destination $diskPath -Force

#  Couldn't get disk number from m.Number below.  Just changed it to G since I know that is the disk we need.
$m = Mount-DiskImage $diskPath -Passthru
#  $size = (Get-PartitionSupportedSize -DiskNumber $m.number -PartitionNumber 2)
#  This command is temp untl I figure out above errors
#  $size = Get-PartitionSupportedSize -DriveLetter G
#  $size = ([math]::Ceiling($($size.SizeMin / 1gb)) + 3) * 1gb
# Below command won't work since m.number isn't valid.  Replaced with line below it for now.
#  Resize-Partition -DiskNumber $m.number -PartitionNumber 2 -Size $size
# Resize-Partition -DriveLetter G -Size $size
Dismount-DiskImage $m.ImagePath
#  Resize-Vhd -ToMinimumSize -Path $m.ImagePath
Convert-VHD -Path $m.ImagePath -DestinationPath $targetDiskPath -VHDType Fixed


$vhd = "ASDK$version.vhd"
$azcopyDestPath = "D:\azcopy.zip"
DownloadWithRetry -Uri https://aka.ms/downloadazcopy-v10-windows -DownloadLocation $azcopyDestPath
Unblock-File -Path $azcopyDestPath
Expand-Archive -Path $azcopyDestPath -DestinationPath D:\azcopy -Force
cd D:\azcopy\*



#  Create Storage and Upload
$saName = "asdk" + $version

New-AzResourceGroup -Name $rg -Location $region
New-AzStorageAccount -Location $region -ResourceGroupName $rg -SkuName Standard_LRS -Name $saName
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $rg -Name $saName).Value[0]
$storageContext = New-AzStorageContext -StorageAccountName $saName -StorageAccountKey $storageAccountKey
$storageContainer = New-AzStorageContainer -Name vhd -Context $storageContext
$storagePolicyName = “vhd-policy”
New-AzStorageContainerStoredAccessPolicy -Container vhd -Policy $storagePolicyName -Permission rwdl -Context $storageContext
$sasToken = (New-AzStorageContainerSASToken -Name vhd -Policy $storagePolicyName -Context $storageContext).substring(1)



#
#Start-AzStorageBlobCopy -AbsoluteUri $sourceUri -DestContainer "vhd" -DestContext $sa.context -DestBlob "cloudbuilder.vhd" -ConcurrentTaskCount 100
#do {
#    Start-Sleep -Seconds 60
#    $result = Get-AzStorageAccount -Name $sa.StorageAccountName -ResourceGroupName $rg | Get-AzStorageBlob -Container "vhd" | Get-AzStorageBlobCopyState
#    $remaining = [Math]::Round(($result.TotalBytes - $result.BytesCopied) / 1gb,2)
#    Write-Verbose -Message "Waiting copy to finish remaining $remaining GB" -Verbose 
#} until ($result.Status -eq "success") 
#

$env:AZCOPY_CRED_TYPE = "Anonymous";
./azcopy.exe copy "$d\$vhd" "https://$saName.blob.core.windows.net/template-vhd/asdk$version.vhd?$sasToken" --overwrite=prompt --follow-symlinks --recursive --from-to=LocalBlob --blob-type=PageBlob --put-md5;
$env:AZCOPY_CRED_TYPE = "";