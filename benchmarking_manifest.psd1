#Configuration data for benchmarking tests

@{
    vcenter            = '192.168.105.101'
    cluster_name       = 'Cluster01'
    VM_count           = 2
    vm_template_name   = 'testvm-win2016-template'

    #diskspd test parameters
    block_size          = '4k'
    duration_in_sec     = 300
    threads             = 4
    OIO                 = 32
    write_percent       = 30
    workload_file_size  = '4G'   

}