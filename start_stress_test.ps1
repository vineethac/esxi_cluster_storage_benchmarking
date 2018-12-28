# Module Name  : Start Stress Test
# Script Name  : start_stress_test.ps1
# Author       : Vineeth A.C.
# Version      : 0.1
# Last Modified: 28/12/2018 (ddMMyyyy)

Begin {
    #Ignore invalid certificate
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Verbose

    #Importing manifest file
    $config_data = Import-PowerShellDataFile -Path .\benchmarking_manifest.psd1 -ErrorAction Stop
    
    try {
        #Connect to VCSA
        Connect-VIServer -Server $config_data.vCenter  
    }
    catch {
        Write-Host "Incorrect vCenter creds!"
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

Process {
    #Invoke diskspd on each stress-test-vm
    get-vm -Name stress-test-vm* | ForEach-Object {Invoke-VMScript -VM $_ -ScriptText  "C:\diskspd.exe -b$($config_data.block_size) -d$($config_data.duration_in_sec) -t$($config_data.threads) -o$($config_data.OIO) -h -r -w$($config_data.write_percent) -L -Z500M -c$($config_data.workload_file_size) E:\io_stress.dat > C:\$_.txt" -ScriptType Powershell -GuestUser administrator -GuestPassword Dell1234 -RunAsync -Verbose -confirm:$false}
    
    #Waiting till test duration
    Write-Host "Storage stress test in progress. Test duration: $($config_data.duration_in_sec) seconds." -ForegroundColor Cyan
    Start-Sleep (($config_data.duration_in_sec)+10) -Verbose
    
    #Copy diskspd logs from stress-test-vms to local machine
    $foldername =(Get-Date).tostring("dd-MM-yyyy-hh-mm-ss")
    get-vm -Name stress-test-vm* | ForEach-Object {Copy-VMGuestFile -Source c:\$_.txt -Destination c:\temp\$foldername\ -VM $_ -GuestToLocal -HostUser vineetha -HostPassword Dell1234 -GuestUser administrator -GuestPassword Dell1234 -Force}
}

End {
    Disconnect-VIServer $config_data.vCenter -Confirm:$false
}
