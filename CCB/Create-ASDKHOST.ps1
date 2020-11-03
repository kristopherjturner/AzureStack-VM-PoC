Connect-AzAccount -Subscription "Turner-CET-Azure"

# Customizable Parameters
$adminPassword = Get-Credential -Credential "Local Admin Password"
$publicDnsName = Read-Host -Prompt "Public DNS prefix"
$region = 'WEST US 2'
$rg = 'ash_asdk_westus2_RG'
New-AzResourceGroup -Name $rg -Location $region

$sourceUri = "https://asdk2005.blob.core.windows.net/vhd/asdk2005.vhd"

#  Add ParameterObjects
$templateParameterObject = @{
    adminPassword = $adminPassword
    publicDnsName = $publicDnsName
    dataDiskCount = 8
    osDiskVhdUri = $sa.PrimaryEndpoints.Blob + "vhd/asdk2005.vhd"
}
New-AzResourceGroupDeployment -ResourceGroupName $rg -Name AzureStackonAzureVM -TemplateUri "https://github.com/kristopherjturner/AzureStack-VM-PoC/blob/master/CCB/azuredeploy.json" -TemplateParameterObject $templateParameterObject

#region 1
#region 2
dasdoksadsd
sad
sadasd
asd
#endregion 2
asd
asd
as

#endregion 1
