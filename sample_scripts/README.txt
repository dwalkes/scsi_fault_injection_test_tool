
These sample shell scripts are wrapper of scsi fault injection
test tool. By using these scripts, error handling routine of md RAID1
and md RAID10 can be easily tested. User can see what is happening
when various kinds of SCSI fault occurs on md RAID.


Requirement
-----------
 - Fedora8 installed only on sda
 - kernel 2.6.22 ~ 2.6.23.14
 - systemtap working environment
 - scsi_fault_injection_test_tool ver 1.0.1 or later
 - At least 3 sata/scsi disks for working md raid array. 
   These should be seen as sdb, sdc, sdd, sde, sdf, ... 
   The first partition (such as sdb1, sdc1, ...) need to be allocated 
   with system ID 0xfd (linux raid autodetect). These partitions should
   be the same size for raid array creation. 
   e.g. By using fdisk command, allocate 2GB of sdb1, sdc1 and sdd1
        with system ID 0xfd.
 - root privilege to run the script.


Usage
-----
 Move to "sample_scripts" directory and run md_scsi_fault_injection_test.sh or 
 md_scsi_fault_injection_test_timeout.sh as follows:
 
 #sh md_scsi_fault_injection_test.sh [scsi|sata] [1|10]
 #sh md_scsi_fault_injection_test_timeout.sh [scsi|sata] [1|10]


Description
-----------
These scripts automatically inject the following scsi faults
one by one on dynamically created md RAID array with the 
following conditions.

Faults: 
 md_scsi_fault_injection_test.sh
  disk_rerr.stp      (permanent read error simulation)
  disk_rwerr.stp     (permanent read /write error simulation)
  sector_rerr.stp    (read error correctable by write simulation)
  temporary_rerr.stp (temporary read error simulation)
  temporary_werr.stp (temporary write error simulation)

 md_scsi_fault_injection_test_timeout.sh
  r_timeout.stp      (temporary no response on read access simulation)
  w_timeout.stp      (temporary no response on  write access simulation)

  for more details, see readme.txt

Conditions:
 normal array     (fully working array)
 degraded array   (array with partially disabled disk)
 redundant array  (normal + spare disk)
 recovering array (array during recovery)

Logs are automatically collected to "results_`date`" directory and named
"disktype"-"raidlevel"-"condition"-"scriptname"_result respectively.
Log consists of systemtap log, /proc/mdstat, a part of syslog and all
command activity in the scripts.
Because log includes all output from systemtap and commands in the scripts,
user need to extract important part from the log to see what happens on each case.

The following sections in the log is important to follow the error
handling of the raid array. At the beginning of each section, the section name
is surrounded  by "########" in the log.

 1. Before fault injection
    In "Creating an array" section, array status taken from /proc/mdstat is
    logged before injecting a fault.

 2. During fault injection
    In "Injecting a fault " section, the outputs of scsi fault injection test tool
    is logged. This section includes target location which would trigger the
    fault when accessed.

 3. After fault injection
    In "After the fault injection. Show the results" section, a part of syslog
    and array status after the fault injection is recorded. In the syslog,
    some error handling activity done by md and scsi layer are recorded,
    which includes fault detection,device detach, recovery sync, etc.
    The array status is taken from /proc/mdstat as before. User can see
    the array status transition by comparing before and after the array status.

    This script verifies the result of access when the fault is injected  by using
    cmp command. If an I/O error or data corruption occurs as a result of fault
    injection, the cmp command result would be nonzero. The result is also
    included in this section.

We will show the details by using a sample log.


Example
-------
#sh md_scsi_fault_injection_test.sh scsi 10

 Inject disk_rerr.stp, disk_rwerr.stp, sector_rerr.stp, temporary_rerr.stp and 
 temporary_werr.stp to normal, degraded, redundant and recovering  conditions of 
 md RAID1 array consists of scsi disks.

#sh md_scsi_fault_injection_test_timeout.sh sata 1

 Inject r_timeout.stp and w_timeout.stp to normal, degraded, redundant and 
 recovering  conditions of md RAID10 array consists of sata disks.

For log analysis explanation, we use "scsi-RAID10-red-disk_rerr.stp.result"
taken on our environment as a sample log. In the following explanation, 
extracted actual messages recorded in the log are enclosed by "-----------".


 1. In "Creating an array" section of the log, tested array status is logged.
    This case, tested array is a fully working RAID10 with a spare disk.
    User can find the following messages.
    ----------------------------------------------------------------
    md0 : active raid10 sdf1[4](S) sde1[3] sdd1[2] sdc1[1] sdb1[0]
          3919616 blocks 64K chunks 2 near-copies [4/4] [UUUU]
    ----------------------------------------------------------------

 2. In "Injecting a fault " section of the log, the following messages appear.
    We can see the row begins with "scsi_decide_disposition" in it. 
    This means a fault is injected on a read access(command= 40) to 
    sdb(major= 8 minor= 16).
    ----------------------------------------------------------------     
      SCSI_DISPATCH_CMD: command= 40  
      SCSI_DISPATCH_CMD: major= 8 minor= 16 
      SCSI_DISPATCH_CMD: flag(0:LBA, 1:inode)= 1 
      SCSI_DISPATCH_CMD: start sector= 81983
      SCSI_DISPATCH_CMD: req bufflen= 16384 
      SCSI_DISPATCH_CMD: inode= 12 
      SCSI_DISPATCH_CMD: scmd = 4147687424 
      SCSI_DISPATCH_CMD: [7]=0 [8]=32 
      SCSI_DISPATCH_CMD: cmd-retries = 0 entire-retry =0 

      SCSI_DISPATCH_CMD: cmd= 4147687424, allowed = 5 retries= 0 
      SCSI_DISPATCH_CMD:scsi_cmnd= 4147687424 (host,channel,id,lun)= (0, 0, 1, 0) 
      SCSI_DISPATCH_CMD:execname=cat, pexecname=sh
      scsi_decide_disposition : major=8 minor=16 scmd=4147687424 
      scsi_next_command : cmd = 4147687424       
    ----------------------------------------------------------------

 3. In "After the fault injection. Show the results  " section of the log, 
    syslog and array status after the fault injection is logged.

    The following messages appear in the log several times. 
    This means that the scsi mid layer found error on sdb several times.
    ----------------------------------------------------------------
      kernel: sd 0:0:1:0: [sdb] Result: hostbyte=DID_OK driverbyte=DRIVER_SENSE,SUGGEST_OK
      kernel: sd 0:0:1:0: [sdb] Sense Key : Medium Error [current] 
      kernel: sd 0:0:1:0: [sdb] Add. Sense: Unrecovered read error - auto reallocate failed
      kernel: end_request: I/O error, dev sdb, sector 81983
    ----------------------------------------------------------------

    So md RAID10 decide to detach sdb from the array.
    ----------------------------------------------------------------
      kernel: raid10: Disk failure on sdb1, disabling device. 
      kernel: #011Operation continuing on 3 devices
    ----------------------------------------------------------------

    This case, md RAID10 array has a spare disk, so recovery begins 
    automatically after sdb is disabled.
    ----------------------------------------------------------------
      kernel: md: recovery of RAID array md0
    ----------------------------------------------------------------

    After the fault injection, the array status shows that the recovery is
    finished and the array is fully working but sdb is detached.
    ----------------------------------------------------------------
      Personalities : [raid10] 
      md0 : active raid10 sdf1[0] sde1[3] sdd1[2] sdc1[1] sdb1[4](F)
            3919616 blocks 64K chunks 2 near-copies [4/4] [UUUU]
    ----------------------------------------------------------------

    This case, the access completed successfully because cmp result is 0.
    ----------------------------------------------------------------
      cmp result = 0
    ----------------------------------------------------------------


Limitations
------------
 - md_scsi_fault_injection_test_timeout.sh may fail because
   root partition can be readonly as a result of timeout injection.

 - Some md bugs recently reported may be reproduce by running
   the scripts, which cause array deadlock.

 - It takes a long time to finish the scripts because 5 * 4  or 2 * 4 fault
   patterns are tested automatically. For example, about 3 minutes required to 
   test a single pattern for 2GB md RAID1 array, so estimated wait time would 
   be 5 * 4 * 3 = 60 minutes for md_scsi_fault_injection_test_timeout.sh
   and 2 * 4 * 3 = 24 minutes for  md_scsi_fault_injection_test_timeout.sh

