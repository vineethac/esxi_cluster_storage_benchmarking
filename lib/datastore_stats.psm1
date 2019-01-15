#Function to collect datastore stats
#$list1 contains list of datastore names
#$list2 contains list of esxi host names

Function datastore_stats ($list1, $list2, $test_duration) {

    Begin {
        
        Write-Host $list1
        Write-Host $list2
        Write-Host $test_duration
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
            $lines = "---------------------------------------------------------"
            $logs+=$lines
            Start-Sleep -Seconds 1
        }
        Until ($TimeNow -ge $TimeEnd)
        return $logs
             
        
    }

}