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
        Connect-VIServer -Server $config_data.vcenter -ErrorAction Stop
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($PSItem)
        Write-Error "Incorrect vCenter creds!" -ErrorAction Stop
    }

    #Cluster details
    $cluster_name = Get-Cluster -Name $config_data.cluster_name
    $hosts_in_cluster = $cluster_name | Get-VMHost

    #Test VM number and parameters
    $VM_count = $config_data.VM_count_per_host

    #Get template
    #The template named "testvm-win2016-template" should be present
    $vm_template = Get-Template -Name $config_data.vm_template_name -Verbose
}

Process {
    #Loop for each host in the cluster
    for ($i=1; $i -le $hosts_in_cluster.Count; $i++) {
        
        #Test datastore name needs to be generalized
        $datastore_name = "vol0$i"
        $host_name = $hosts_in_cluster.Name[$i-1]

        #Loop for deploying testvms on each host
        for ($j=1; $j -le $VM_count; $j++) {
            
            #Create VM
            $VM_name = "stress-test-vm-$host_name-$j"
            New-VM -Name $VM_name -VMHost $host_name -ResourcePool $cluster_name -Datastore $datastore_name -Template $vm_template -Verbose | New-HardDisk -CapacityGB $config_data.disk_size -StorageFormat EagerZeroedThick -Persistence persistent -Verbose | New-ScsiController -Type ParaVirtual -Verbose
            Write-Verbose -Message "$VM_name created" -Verbose

            #Start VM
            Get-VM -Name $VM_name | Start-VM -Verbose
            
            #Add few seconds wait time for VMtools to load (a check to be added here)
            Start-Sleep 5 -Verbose

            #Create stress disk and format volume
            Invoke-VMScript -VM $VM_name -ScriptText { Initialize-Disk -Number 1 -PartitionStyle GPT;
                New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter E;
                Get-Volume | where DriveLetter -eq E | Format-Volume -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel Test_disk -confirm:$false  } -ScriptType Powershell -GuestUser administrator -GuestPassword Dell1234 -Verbose -ToolsWaitSecs 60
            Write-Verbose -Message "Drive E initialized partitioned and formatted as NTFS with AUS 64K" -Verbose

            #Set pvscsi queue depth to 254
            $set_pvscsi_cmd = 'REG ADD HKLM\SYSTEM\CurrentControlSet\services\pvscsi\Parameters\Device /v DriverParameter /t REG_SZ /d "RequestRingPages=32,MaxQueueDepth=254"'
            Invoke-VMScript -VM $VM_name -ScriptText $set_pvscsi_cmd -ScriptType Powershell -GuestUser administrator -GuestPassword Dell1234 -Verbose -ToolsWaitSecs 60
            Write-Verbose -Message "pvscsi queue depth set to 254" -Verbose

            Get-VM -Name $VM_name | Restart-VMGuest -Verbose
            
        }
    }
}

End {
    #Disconnect session
    Disconnect-VIServer $config_data.vCenter -Confirm:$false
}

