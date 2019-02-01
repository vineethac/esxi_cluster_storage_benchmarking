#Configuration data for benchmarking tests

@{
    'profile01' = @{
        #diskspd test parameters
        block_size          = '4k'
        duration_in_sec     = 3600
        threads             = 4
        OIO                 = 16
        write_percent       = 0
        access_pattern      = 'r'
        workload_file_size  = '4G'
    }
    
    'profile02' = @{
        #diskspd test parameters
        block_size          = '4k'
        duration_in_sec     = 3600
        threads             = 4
        OIO                 = 16
        write_percent       = 100
        access_pattern      = 's'
        workload_file_size  = '4G'

    }

    'profile03' = @{
        #diskspd test parameters
        block_size          = '4k'
        duration_in_sec     = 600
        threads             = 4
        OIO                 = 16
        write_percent       = 30
        access_pattern      = 's'
        workload_file_size  = '4G'

    }

    'profile04' = @{
        #diskspd test parameters
        block_size          = '8k'
        duration_in_sec     = 3600
        threads             = 4
        OIO                 = 16
        write_percent       = 30
        access_pattern      = 's'
        workload_file_size  = '4G'

    }

    'profile05' = @{
        #diskspd test parameters
        block_size          = '64k'
        duration_in_sec     = 1800
        threads             = 4
        OIO                 = 16
        write_percent       = 30
        access_pattern      = 'r'
        workload_file_size  = '4G'

    }

}