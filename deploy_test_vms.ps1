# Module Name  : Deploy Test VMs
# Script Name  : deploy_test_vms.ps1
# Author       : Vineeth A.C.
# Version      : 0.1
# Last Modified: 19/12/2018 (ddMMyyyy)

Begin {
    #Ignore invalid certificate
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Verbose

    #Importing manifest file
    $config_data = Import-PowerShellDataFile -Path .\benchmarking_manifest.psd1 -ErrorAction Stop
    
    try {
        #Connect to VCSA
        Write-Verbose -Message "Connecting to vCenter $($config_data.vCenter). Provide vCenter creds!" -Verbose
        Connect-VIServer -Server $config_data.vcenter -ErrorAction Stop
    }
    catch {
        Write-Error "Incorrect vCenter creds!" -ErrorAction Stop
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }

    #Cluster details
    $cluster_name = Get-Cluster -Name $config_data.cluster_name
    $hosts_in_cluster = $cluster_name | Get-VMHost
    
    #DRS check
    if ("$($cluster_name.DrsEnabled)" -eq 'True') {
        #Disconnect session
        Disconnect-VIServer $config_data.vCenter -Confirm:$false
        Write-Error -Message "Disable DRS and re-run the script!" -ErrorAction Stop
    }

    #Check for number of datastores equals number of hosts in cluster
    if($hosts_in_cluster.Count -ne $config_data.datastore_names.Count) {
        #Disconnect session
        Disconnect-VIServer $config_data.vCenter -Confirm:$false
        Write-Error -Message "Number of datastores should be equal to number of hosts in the cluster!" -ErrorAction Stop
    }

    #Collecting stress-test-vm guest OS creds
    try {
        Write-Verbose -Message "Collecting stress-test-vm guest OS Creds" -Verbose
        $guest_os_creds = Get-Credential -Message "Enter stress-test-vm guest OS Creds" -UserName administrator
    }
    catch {
        Write-Error -Message "[EndRegion] Failed collecting gateway creds. Exiting!" -Verbose -ErrorAction Stop
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }

    #Test VM number and parameters
    $VM_count = $config_data.VM_count_per_host

    #Datastore list
    $datastore_list = $config_data.datastore_names

    #Get template
    #The template named "testvm-win2016-template" should be present
    $vm_template = Get-Template -Name $config_data.vm_template_name -Verbose -ErrorAction Stop
}

Process {
    #Loop for each host in the cluster
    for ($i=1; $i -le $hosts_in_cluster.Count; $i++) {
        
        #Test datastore name needs to be generalized
        $datastore_name = $datastore_list[$i-1]
        $host_name = $hosts_in_cluster.Name[$i-1]

        #Loop for deploying testvms on each host
        for ($j=1; $j -le $VM_count; $j++) {
            
            #Create VM
            $VM_name = "stress-test-vm-$host_name-$j"
            New-VM -Name $VM_name -VMHost $host_name -ResourcePool $cluster_name -Datastore $datastore_name -Template $vm_template -Verbose | New-HardDisk -CapacityGB $config_data.disk_size -StorageFormat EagerZeroedThick -Persistence persistent -Verbose | New-ScsiController -Type ParaVirtual -Verbose
            Write-Verbose -Message "$VM_name created" -Verbose

            #Start VM
            Get-VM -Name $VM_name | Start-VM -Verbose
            
            #Add few seconds wait time for VMtools to load 
            Start-Sleep 5 -Verbose

            #Verify status of VM tools
            do { $stat = (Get-VM $VM_name).ExtensionData.Guest.ToolsStatus; write-host "$VM_name $stat"; Start-Sleep 2 } until ($stat -eq 'toolsOk') 

            #Initialize and partition stress disk
            Invoke-VMScript -VM $VM_name -ScriptText {Initialize-Disk -Number 1 -PartitionStyle GPT;
            New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter E} -ScriptType Powershell -GuestCredential $guest_os_creds -Verbose -ToolsWaitSecs 60
            
            #Format stress disk and set aus
            $aus = $config_data.disk_aus_in_bytes
            Invoke-VMScript -VM $VM_name -ScriptText "Format-Volume -DriveLetter E -FileSystem NTFS -AllocationUnitSize '$aus' -NewFileSystemLabel Test_disk" -ScriptType Powershell -GuestCredential $guest_os_creds -Verbose -ToolsWaitSecs 60
            Write-Verbose -Message "Drive E initialized partitioned and formatted as NTFS with specified AUS" -Verbose

            #Set pvscsi queue depth to 254
            $set_pvscsi_cmd = 'REG ADD HKLM\SYSTEM\CurrentControlSet\services\pvscsi\Parameters\Device /v DriverParameter /t REG_SZ /d "RequestRingPages=32,MaxQueueDepth=254"'
            Invoke-VMScript -VM $VM_name -ScriptText $set_pvscsi_cmd -ScriptType Powershell -GuestCredential $guest_os_creds -Verbose -ToolsWaitSecs 60
            Write-Verbose -Message "pvscsi queue depth set to 254" -Verbose

            #Reboot VM
            Get-VM -Name $VM_name | Restart-VMGuest -Verbose
        }
    }
}

End {
    #Disconnect session
    Disconnect-VIServer $config_data.vCenter -Confirm:$false
}

