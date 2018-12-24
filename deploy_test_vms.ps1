# Module Name  : Deploy Test VMs
# Script Name  : deploy_test_vms.ps1
# Author       : Vineeth A.C.
# Version      : 0.1
# Last Modified: 19/12/2018 (ddMMyyyy)

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [String]$vcenter
)
Begin {
    #Ignore invalid certificate
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Verbose

    try {
        #Connect to VCSA
        Connect-VIServer -Server $vcenter  
    }
    catch {
        Write-Host "Incorrect vCenter creds!"
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }

    #Cluster details
    $cluster_name = Get-Cluster -Name Cluster01
    $hosts_in_cluster = $cluster_name | Get-VMHost

    #Test VM number and parameters
    $VM_count = 2

    #Get template
    #The template named "testvm-win2016-template" should be present
    $vm_template = Get-Template -Name "testvm-win2016-template" -Verbose
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
            New-VM -Name $VM_name -VMHost $host_name -ResourcePool $cluster_name -Datastore $datastore_name -Template $vm_template | New-HardDisk -CapacityGB 6 -Persistence persistent | New-ScsiController -Type ParaVirtual -Verbose
            
            #Start VM
            Get-VM -Name $VM_name | Start-VM
            
            #Create stress disk and format volume
            Invoke-VMScript -VM $VM_name -ScriptText { Initialize-Disk -Number 1 -PartitionStyle GPT;
                New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter E;
                Get-Volume | where DriveLetter -eq E | Format-Volume -FileSystem NTFS -NewFileSystemLabel Test_disk -confirm:$false  } -ScriptType Powershell -GuestUser administrator -GuestPassword Dell1234 


        }
    }
}

End {
    #Disconnect session
    Disconnect-VIServer $vcenter -Confirm:$false
}

