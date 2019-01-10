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
    $profile_data = Import-PowerShellDataFile -Path .\profile_manifest.psd1 -ErrorAction Stop
    
    try {
        #Connect to VCSA
        Connect-VIServer -Server $config_data.vCenter -ErrorAction Stop
    }
    catch {
        Write-Error "Incorrect vCenter creds!" -ErrorAction Stop
        $PSCmdlet.ThrowTerminatingError($PSItem)
    }
}

Process {
    #Get all profile data keys
    $all_keys = $profile_data.GetEnumerator() | ForEach-Object {$_.Key}

    #For reach profile defined in manifest2 do following
    for ($i=0; $i -lt $profile_data.Keys.Count; $i++) {
        #Invoke diskspd on each stress-test-vm
        get-vm -Name stress-test-vm* | ForEach-Object {Invoke-VMScript -VM $_ -ScriptText  "C:\diskspd.exe -b$($profile_data.$($all_keys[$i]).block_size) -d$($profile_data.$($all_keys[$i]).duration_in_sec) -t$($profile_data.$($all_keys[$i]).threads) -o$($profile_data.$($all_keys[$i]).OIO) -h -r -w$($profile_data.$($all_keys[$i]).write_percent) -L -Z500M -c$($profile_data.$($all_keys[$i]).workload_file_size) E:\io_stress.dat > C:\$_.txt" -ScriptType Powershell -GuestUser administrator -GuestPassword Dell1234 -RunAsync -Verbose -confirm:$false}
        
        #Waiting till test duration
        Write-Verbose "$($all_keys[$i]): Storage stress test in progress. Test duration: $($profile_data.$($all_keys[$i]).duration_in_sec) seconds. Please wait!" -Verbose
        Start-Sleep (($profile_data.$($all_keys[$i]).duration_in_sec)+30) -Verbose
        
        #Copy diskspd logs from stress-test-vms to local machine
        Write-Verbose "Copying diskspd logs to local machine" -Verbose
        $foldername = (Get-Date).tostring("dd-MM-yyyy-hh-mm-ss")+"-"+$all_keys[$i]
        get-vm -Name stress-test-vm* | ForEach-Object {Copy-VMGuestFile -Source c:\$_.txt -Destination c:\temp\$foldername\ -VM $_ -GuestToLocal -HostUser vineetha -HostPassword Dell1234 -GuestUser administrator -GuestPassword Dell1234 -Force -ToolsWaitSecs 30} -Verbose
        
        Start-Sleep 10 -Verbose
        Write-Verbose "Restarting all stress-test-vms"
        Get-VM -Name stress-test-vm* | Restart-VMGuest
        Start-Sleep 10 -Verbose
    }
}

End {
    Disconnect-VIServer $config_data.vCenter -Confirm:$false
}
