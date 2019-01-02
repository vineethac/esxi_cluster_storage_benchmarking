#Configuration data for benchmarking tests

@{
    'profile01' = @{
        #diskspd test parameters
        block_size          = '4k'
        duration_in_sec     = 300
        threads             = 4
        OIO                 = 32
        write_percent       = 0
        workload_file_size  = '4G'
    }
    
    'profile02' = @{
        #diskspd test parameters
        block_size          = '8k'
        duration_in_sec     = 300
        threads             = 4
        OIO                 = 32
        write_percent       = 30
        workload_file_size  = '4G'

    }

}