$subscriber_name="Azure Pass"   						# Subscription Name
$resourcegroup_name = "deloitteauits3"	 				# Resource Group Name
$location_name = "eastus" 								# Location Name
$storage_account_name = "deloitteaustorage3"			# Storage Account Name
$storage_account_type="Standard_LRS"					# Storage Account Type
$domain_name = "deloitteauits3"							# Domain Name
$availability_set_name = "deloitteavset3"				# Availability Set Name
$virtual_network_name = "deloitteauvirtualnetwork3"		# Virtual Network Name
$public_ip_name = "deloittepublicip3"					# Public IP Name
$load_balancer_name = "deloitteloadbalancer3"			# Load Balancer Name

# Login to Azure Account
Login-AzureRmAccount

# Get-AzureRmSubscription | Sort SubscriptionName | Select SubscriptionName
Get-AzureRmSubscription –SubscriptionName $subscriber_name | Select-AzureRmSubscription

# Create New Resource Group
New-AzureRmResourceGroup -Name $resourcegroup_name -Location $location_name
# Checks Resource Group
Get-AzureRmResourceGroup | Sort ResourceGroupName | Select ResourceGroupName

# Create New Storage Account
New-AzureRmStorageAccount -Name $storage_account_name -ResourceGroupName $resourcegroup_name –Type $storage_account_type -Location $location_name
# Checks Storage Account
Get-AzureRmStorageAccount

# Checks if Domain Qualified Name is available or not
Test-AzureRmDnsAvailability -DomainQualifiedName $domain_name -Location $location_name

# Creates Avalibility Set
New-AzureRmAvailabilitySet –Name $availability_set_name –ResourceGroupName $resourcegroup_name -Location $location_name
# Checks created Availability Set
Get-AzureRmAvailabilitySet –ResourceGroupName $resourcegroup_name | Sort Name | Select Name

# Declaring Frontend Subnet of Virtual Network
$frontendSubnet=New-AzureRmVirtualNetworkSubnetConfig -Name frontendSubnet -AddressPrefix 10.0.1.0/24

# Declaring Backend Subnet of Virtual Network
$backendSubnet=New-AzureRmVirtualNetworkSubnetConfig -Name backendSubnet -AddressPrefix 10.0.2.0/24

# Creating Virtual Network with Two Subnets 
New-AzureRmVirtualNetwork -Name $virtual_network_name -ResourceGroupName $resourcegroup_name -Location $location_name -AddressPrefix 10.0.0.0/16 -Subnet $frontendSubnet,$backendSubnet
# Checks the created Virtual Network
Get-AzureRmVirtualNetwork -ResourceGroupName $resourcegroup_name | Sort Name | Select Name

# Declaring Public IP Address
$publicIP = New-AzureRmPublicIpAddress -Name $public_ip_name -ResourceGroupName $resourcegroup_name -Location $location_name –AllocationMethod Dynamic -DomainNameLabel $domain_name
# Checking Public IP Address 
Get-AzureRMPublicIPAddress –Name $public_ip_name –ResourceGroupName $resourcegroup_name

# Declaring Frontend IP Pool
$frontendIP = New-AzureRmLoadBalancerFrontendIpConfig -Name LoadBalancer-Frontend -PublicIpAddress $publicIP

# Declaring Backend IP Pool 
$beaddresspool= New-AzureRmLoadBalancerBackendAddressPoolConfig -Name "LoadBalancer-Backend"

# Declaring Inbound Nat Rule 1
$inboundNATRule1= New-AzureRmLoadBalancerInboundNatRuleConfig -Name "RDP1" -FrontendIpConfiguration $frontendIP -Protocol TCP -FrontendPort 3441 -BackendPort 3389
# Declaring Inbound Nat Rule 2
$inboundNATRule2= New-AzureRmLoadBalancerInboundNatRuleConfig -Name "RDP2" -FrontendIpConfiguration $frontendIP -Protocol TCP -FrontendPort 3442 -BackendPort 3389
 
# Declaring a Health Probe
$healthProbe = New-AzureRmLoadBalancerProbeConfig -Name "HealthProbe" -RequestPath "/" -Protocol http -Port 80 -IntervalInSeconds 15 -ProbeCount 2

# Create Load Balancer Rule 
$lbrule = New-AzureRmLoadBalancerRuleConfig -Name "HTTP" -FrontendIpConfiguration $frontendIP -BackendAddressPool $beAddressPool -Probe $healthProbe -Protocol Tcp -FrontendPort 80 -BackendPort 80

# Create Load Balancer with declared variables
$Lab5LB = New-AzureRmLoadBalancer -ResourceGroupName $resourcegroup_name -Name $load_balancer_name -Location $location_name -FrontendIpConfiguration $frontendIP -InboundNatRule $inboundNATRule1,$inboundNatRule2 -LoadBalancingRule $lbrule -BackendAddressPool $beAddressPool -Probe $healthProbe 



# Set values for existing resource group and storage account names
#$resourcegroup_name="[Your-resourcegroup-name]"
#$location_name="[Your-region-name]"
#$storage_account_name="[Your-storage-account-name]"

# Set the existing virtual network and subnet index
$subnetIndex=0
$vnet=Get-AzureRmVirtualNetwork -Name $virtual_network_name -ResourceGroupName $resourcegroup_name


# Create the NIC

$nicName="DELOITTENIC"
#$load_balancer_name="lab5-LB"
$bePoolIndex=0
$natRuleIndex=0
$lb=Get-AzureRmLoadBalancer -Name $load_balancer_name -ResourceGroupName $resourcegroup_name
$nic=New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $resourcegroup_name -Location $location_name -Subnet $vnet.Subnets[$subnetIndex] -LoadBalancerBackendAddressPool $lb.BackendAddressPools[$bePoolIndex] -LoadBalancerInboundNatRule $lb.InboundNatRules[$natRuleIndex]


# Specify the name, size, and existing availability set
$vmName="DeloitteVM1"
$vmSize="Standard_A3"
#$availability_set_name="[Your-availability-set-name]"
$avSet=Get-AzureRmAvailabilitySet -ResourceGroupName $resourcegroup_name -Name $availability_set_name
$vm=New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize -AvailabilitySetId $avset.Id

# Add a 200 GB additional data disk
$diskSize=100
$diskLabel="APPStorage"
$diskName="21050529-DISK02"
$storageAcc=Get-AzureRmStorageAccount -ResourceGroupName $resourcegroup_name -Name $storage_account_name
$vhdURI=$storageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName + $diskName  + ".vhd"
Add-AzureRmVMDataDisk -VM $vm -Name $diskLabel -DiskSizeInGB $diskSize -VhdUri $vhdURI -CreateOption empty

# Specify the image and local administrator account, and then add the NIC
$pubName="MicrosoftWindowsServer"
$offerName="WindowsServer"
$skuName="2012-R2-Datacenter"
$cred=Get-Credential -Message "Type the name and password of the local administrator account."
$vm=Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
$vm=Set-AzureRmVMSourceImage -VM $vm -PublisherName $pubName -Offer $offerName -Skus $skuName -Version "latest"
$vm=Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id

# Specify the OS disk name and create the VM
$diskName="OSDisk"
$storageAcc=Get-AzureRmStorageAccount -ResourceGroupName $resourcegroup_name -Name $storage_account_name
$osDiskUri=$storageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName + $diskName  + ".vhd"
$vm=Set-AzureRmVMOSDisk -VM $vm -Name $diskName -VhdUri $osDiskUri -CreateOption fromImage
New-AzureRmVM -ResourceGroupName $resourcegroup_name -Location $location_name -VM $vm

# Create the NIC2

$nicName2="DELOITTENIC2"
$bePoolIndex2=1
$natRuleIndex2=1
$lb=Get-AzureRmLoadBalancer -Name $load_balancer_name -ResourceGroupName $resourcegroup_name
$nic=New-AzureRmNetworkInterface -Name $nicName2 -ResourceGroupName $resourcegroup_name -Location $location_name -Subnet $vnet.Subnets[$subnetIndex] -LoadBalancerBackendAddressPool $lb.BackendAddressPools[$bePoolIndex2] -LoadBalancerInboundNatRule $lb.InboundNatRules[$natRuleIndex2]


# Specify the name, size, and existing availability set
$vmName2="DeloitteVM2"
$vmSize="Standard_A3"
$avSet=Get-AzureRmAvailabilitySet -ResourceGroupName $resourcegroup_name -Name $availability_set_name
$vm2=New-AzureRmVMConfig -VMName $vmName2 -VMSize $vmSize -AvailabilitySetId $avset.Id

# Add a 200 GB additional data disk
$diskSize2=100
$diskLabel2="APPStorage2"
$diskName2="21050529-DISK03"
$storageAcc=Get-AzureRmStorageAccount -ResourceGroupName $resourcegroup_name -Name $storage_account_name
$vhdURI=$storageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName2 + $diskName2  + ".vhd"
Add-AzureRmVMDataDisk -VM $vm2 -Name $diskLabel2 -DiskSizeInGB $diskSize2 -VhdUri $vhdURI -CreateOption empty

# Specify the image and local administrator account, and then add the NIC
$pubName="MicrosoftWindowsServer"
$offerName="WindowsServer"
$skuName="2012-R2-Datacenter"
$cred=Get-Credential -Message "Type the name and password of the local administrator account."
$vm2=Set-AzureRmVMOperatingSystem -VM $vm2 -Windows -ComputerName $vmName2 -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
$vm2=Set-AzureRmVMSourceImage -VM $vm2 -PublisherName $pubName -Offer $offerName -Skus $skuName -Version "latest"
$vm2=Add-AzureRmVMNetworkInterface -VM $vm2 -Id $nic.Id

# Specify the OS disk name and create the VM
$diskName2="OSDisk2"
$storageAcc=Get-AzureRmStorageAccount -ResourceGroupName $resourcegroup_name -Name $storage_account_name
$osDiskUri=$storageAcc.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName2 + $diskName2  + ".vhd"
$vm2=Set-AzureRmVMOSDisk -VM $vm2 -Name $diskName2 -VhdUri $osDiskUri -CreateOption fromImage
New-AzureRmVM -ResourceGroupName $resourcegroup_name -Location $location_name -VM $vm2