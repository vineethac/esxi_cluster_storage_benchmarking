#Function to collect datastore stats
#$list1 contains list of datastore names
#$list2 contains list of esxi host names
#$test_duration is the time for each profile run in seconds
Function datastore_stats ($list1, $list2, $test_duration) {

    Begin {
        
        #Might need to refactor this function!
    }

    Process {
        #Function to collect datastore performance stats
        Function datastore_perf ($host_name) {

            $stat_array =@()

            For ($i = 0; $i -lt $list1.count; $i++){ 
                $datastore_name = $list1[$i]
                
                if($datastore_name) {
                    $instance_id = (Get-Datastore $datastore_name).ExtensionData.Info.Vmfs.Uuid
                
                    $t1 = Get-Stat -Entity $host_name -Stat datastore.numberReadAveraged.average -MaxSamples 1 -Realtime -Instance $instance_id 
                    $t2 = Get-Stat -Entity $host_name -Stat datastore.numberWriteAveraged.average -MaxSamples 1 -Realtime -Instance $instance_id 
                    $t3 = Get-Stat -Entity $host_name -Stat datastore.totalReadLatency.average -MaxSamples 1 -Realtime -Instance $instance_id 
                    $t4 = Get-Stat -Entity $host_name -Stat datastore.totalWriteLatency.average -MaxSamples 1 -Realtime -Instance $instance_id 
                    $t5 = Get-Stat -Entity $host_name -Stat datastore.datastoreMaxQueueDepth.latest -MaxSamples 1 -Realtime -Instance $instance_id
                    $t6 = Get-Stat -Entity $host_name -Stat datastore.read.average -MaxSamples 1 -Realtime -Instance $instance_id
                    $t7 = Get-Stat -Entity $host_name -Stat datastore.write.average -MaxSamples 1 -Realtime -Instance $instance_id

                    $stat_object = New-Object System.Object
                
                    $read_iops = $t1[0].Value
                    $write_iops = $t2[0].Value
                    $read_latency = $t3[0].Value
                    $write_latency = $t4[0].Value
                    $max_queue_depth = $t5[0].Value
                    $read_avg = $t6[0].Value
                    $write_avg = $t7[0].Value

                    $stat_object | Add-Member -Type NoteProperty -Name ESXi -Value "$host_name"
                    $stat_object | Add-Member -Type NoteProperty -Name Datastore -Value "$datastore_name"
                    $stat_object | Add-Member -Type NoteProperty -Name ReadIOPS -Value "$read_iops"
                    $stat_object | Add-Member -Type NoteProperty -Name WriteIOPS -Value "$write_iops"
                    $stat_object | Add-Member -Type NoteProperty -Name ReadLatency[ms] -Value "$read_latency"
                    $stat_object | Add-Member -Type NoteProperty -Name WriteLatency[ms] -Value "$write_latency"
                    $stat_object | Add-Member -Type NoteProperty -Name MaxQueueDepth -Value "$max_queue_depth"
                    $stat_object | Add-Member -Type NoteProperty -Name ReadRate[KBps] -Value "$read_avg"
                    $stat_object | Add-Member -Type NoteProperty -Name WriteRate[KBps] -Value "$write_avg"
                
                    $stat_array += $stat_object
                }
            }

            return ($stat_array | Format-Table)
        }
    }

    End {
        
        #setup loop
        $TimeStart = Get-Date
        $TimeEnd = $timeStart.AddSeconds($test_duration)
        
        Do { 
            $TimeNow = Get-Date
            $result = $list2 | ForEach-Object { datastore_perf -host_name $PSItem }
            #$result | Out-File -FilePath C:\temp\datastore_stats.txt -Append
            $logs+=$result

            $time_stamp =(Get-Date).tostring("dd-MM-yyyy-hh-mm-ss")
            $line_break = "********** $time_stamp **********"
            $logs+=$line_break
            Start-Sleep -Seconds 1
        }
        Until ($TimeNow -ge $TimeEnd)
        
        #Write-Verbose -Message "Datastore level log collection completed" -Verbose
        return $logs
             
        
    }
}

#Function to connect to VxFlex OS REST API
Function Connect_VxFlexOS {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]$gateway,
        $Credentials
    )
    Process {
        #To fix the connection issues to scaleio rest api
        add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
            }
        }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11

        #authentication step with AMS server and token generation
        
        
        #token generation
        try { 
            Write-Verbose -Message "Prerequisite - creating token" -Verbose
            Write-Verbose -Message "Connecting to ScaleIO Gateway: $gateway" -Verbose
            $Token = Invoke-RestMethod -Uri "https://$($gateway):443/api/login" -Method Get -Credential $Credentials 
        }
        catch {
            Write-Error -Message "Failed to create token. Quiting!" -ErrorAction Stop -Verbose
            #Write-VerboseLog -ErrorInfo $PSItem
            #Stop-Transcript
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }

        #creating header
        try {
            $auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(':'+$Token))
            $global:ScaleIOAuthHeaders = @{'Authorization' = "Basic $auth" 
            'Content-Type' = "application/json" }
            Write-Verbose -Message "Header created" -Verbose
            return $global:ScaleIOAuthHeaders

            }
        catch {
            Write-Error -Message "Failed creating auth header. Quiting!" -ErrorAction Stop -Verbose
            #Write-VerboseLog -ErrorInfo $PSItem
            #Stop-Transcript
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}

#Function to collect VxFlex OS PD perf logs
Function PD_perf_logs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $gateway,
        $ScaleIOAuthHeaders,
        $PD_id,
        $test_duration
    )

    Begin {
        
        #To fix the connection issues to scaleio rest api
        add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
            }
        }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11

        $param1 = @'
        {
            "allIds":[""],"properties":["primaryReadBwc","primaryWriteBwc"]
        }
'@ 
        $logs2 =@()

        $time_stamp =(Get-Date).tostring("dd-MM-yyyy-hh-mm-ss")
        $line_break = "********** $time_stamp **********"
        $logs2+=$line_break
    }
    Process {

        
        #setup loop
        $TimeStart = Get-Date
        $TimeEnd = $timeStart.AddSeconds($test_duration)
        
        Do { 
            $TimeNow = Get-Date
            $PD_perf_logs = (Invoke-RestMethod -Uri "https://$($gateway):443/api/types/ProtectionDomain/instances/action/querySelectedStatistics" -Body $param1 -ContentType "application/json" -Headers $ScaleIOAuthHeaders -Method Post)    
            
            
            if(($PD_perf_logs.$($PD_id).primaryReadBwc.numSeconds) -ne '0' -And ($PD_perf_logs.$($PD_id).primaryReadBwc.numSeconds) -ne '0') {
                $read_IOPS = ($PD_perf_logs.$($PD_id).primaryReadBwc.numOccured)/($PD_perf_logs.$($PD_id).primaryReadBwc.numSeconds)
                $write_IOPS = ($PD_perf_logs.$($PD_id).primaryWriteBwc.numOccured)/($PD_perf_logs.$($PD_id).primaryWriteBwc.numSeconds)
                $read_bw_in_Kb = ($PD_perf_logs.$($PD_id).primaryReadBwc.totalWeightInKb)/($PD_perf_logs.$($PD_id).primaryReadBwc.numSeconds)
                $write_bw_in_Kb = ($PD_perf_logs.$($PD_id).primaryWriteBwc.totalWeightInKb)/($PD_perf_logs.$($PD_id).primaryWriteBwc.numSeconds)
            }
            $PD_stat_object = New-Object System.Object

            $PD_stat_object | Add-Member -Type NoteProperty -Name PD_ID -Value "$PD_id"
            $PD_stat_object | Add-Member -Type NoteProperty -Name Read_IOPS -Value "$read_IOPS"
            $PD_stat_object | Add-Member -Type NoteProperty -Name Write_IOPS -Value "$write_IOPS"
            $PD_stat_object | Add-Member -Type NoteProperty -Name Read_BW_in_MB -Value "$($read_bw_in_Kb/1024)"
            $PD_stat_object | Add-Member -Type NoteProperty -Name Write_BW_in_MB -Value "$($write_bw_in_Kb/1024)"
            
            $logs2+=$PD_stat_object
            
            Start-Sleep -Seconds 5
        }
        Until ($TimeNow -ge $TimeEnd)
    }
    End {

        $time_stamp =(Get-Date).tostring("dd-MM-yyyy-hh-mm-ss")
        $line_break = "********** $time_stamp **********"
        $logs2+=$line_break
        
        #Write-Verbose -Message "PD log collection completed" -Verbose
        return ($logs2 | Format-Table)
    }
    
}    