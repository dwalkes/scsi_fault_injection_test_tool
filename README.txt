
The SCSI fault injection test tool

Revision History:

  rev 1.00  Jan 18 2008 K.Tanaka
    -   Initial Release.


1. Introduction
================
This tool enables to test error handling routines related with the filesystem 
and block I/O of the Linux system by injecting a SCSI fault on the system.

This tool generates "pseudo" faults in the SCSI mid-layer. This could be 
a more realistic SCSI device faults simulation. For example, device faults 
resulting in scsi command timeout, and media faults which could be corrected by 
writing data to the failed sector could be simulated.
User can designate a device currently connected to the system and the target
location within the designated device to inject a fault, so that test program
using this tool could generate an error with a specific access.

Internally, this tool uses SystemTap. This tool rewrite the status code and 
sense data of SCSI command using SytemTap and pass it to the upper layer. 
So the real error handling routine of the upper layer for I/O request can be tested.

This is originally created to test  software RAID (md/dm-mirror)
on Linux. But any upper layer app/driver using the SCSI mid-layer can also apply 
this tool. 


2. Requirements
================
- Linux system (x86 architecture) compiled with debuginfo.
- SystemTap (v5.14.1 or later) installed to the Linux system.

Please see http://sourceware.org/systemtap/index.html for SystemTap.


3. Supported SCSI fault type
============================

This test tool supports to inject the following type of faults. 

3-1. Permanent read error simulation
     This type of fault simulates a permanent media error
     on a particular sector. Any read access to the sector fails, 
     but write will succeed.

3-2. Permanent read /write error simulation
     This type of fault simulates a severe media error.
     Both read and write fails on the particular sector permanently.

3-3. Read error correctable by write simulation
     This type of fault simulates a media fault which could be 
     corrected by writing data to the failed sector. After writing
     to the sector, subsequent reads and writes will both succeed.

3-4. Temporary read error simulation
     This type of fault simulates an accidental fault, just once.

3-5. Temporary write error simulation
     This type of fault simulates an accidental fault, just once.

3-6. Temporary no response on a read access simulation
     This type of fault simulates a situation,such as a congestion,
     resulting in scsi command timeout on a read request. After 
     the congestion disappears, both read and write will succeed.

3-7. Temporary no response on a write access simulation 
     This type of fault simulates a situation,such as a congestion,
     resulting in scsi command timeout on a write request. After 
     the congestion disappears, both read and write will succeed.

3-8. Permanent no response on both read and write access simulation
     This type of fault simulates a device fault resulting in scsi 
     command timeout on a write request. 
     Both read and write fails on the particular sector permanently.


Each fault type can be injected by using SystemTap scripts(*.stp) for each type.

  script name       |       fault type description
 -------------------+-------------------------------------------------------
 disk_rerr.stp      | permanent read error simulation
 disk_rwerr.stp     | permanent read /write error simulation
 sector_rerr.stp    | read error correctable by write simulation
 temporary_rerr.stp | temporary read error simulation
 temporary_werr.stp | temporary write error simulation
 r_timeout.stp      | temporary no response on read access simulation
 w_timeout.stp      | temporary no response on  write access simulation 
 rw_timeout.stp     | permanent no response on both read and write access simulation

disk_rwerr.stp, disk_rerr.stp, sector_rerr.stp, temporary_rerr.stp, temporary_werr.stp
return a "fake" sense data(sense key = 3, ASC = 11, ASCQ = 4) to the upper layer. 
This means a medium error.

The following scripts are also included, but they are for internal use only.
 scsi_fault_injection_common.stp   - common routine for fault injection
 scsi_timeout_injection_common.stp - common routine for timeout injection


4. Usage
=========

The flow is as follows. 
For more detailed example, see the sample_usage.txt.	

1. Setup
  1-1  Install SystemTap and kernel with debuginfo.
       (For more details, see Appendix A)

  1-2  Decompress toolset and move them to an arbitrary directory.


2. Decide the type and target of the fault

  2-1 Fault type
      Choose a fault type you want to inject described above.

  2-2 Target 
      Choose a target device to inject a fault.
      You need to know the (major, minor) number of the target SCSI device.
      If you want to inject a fault by accessing particular file, 
      you need to know the inode number of the file. (e.g. by ls -i command)
      Also, if you want to inject a fault by accessing particular 
      LBA(Logical Block Address) of the target SCSI device, instead 
      of accessing a file, you need to choose the LBA number.

      NOTE. The file, with which you want to inject a fault may be cached
            on memory, but an access to the target device needs to be generated 
            to inject a fault. For confirmation, you should drop all page 
            caches by "echo 1 > /proc/sys/vm/drop_caches".

           
3. Run the stap command

   Run a script to setup a SystemTap hook to cause a fault. Refer to section
   "6. Scripts usage details" for more details.
   By running a script, the hook for injecting a fault is made. 
   If SystemTap shows the string "Pass 5: starting run.", it's ready.


4. Access the target device

   Running the SystemTap script is just only to set a trap. So an access to the target 
   device is needed to inject the fault.
   e.g. If you run "disk_rerr.stp" script, you need to read from the target device
        You can make a read access by a cat command.
        If you run "temporary_werr.stp you need to write to the target device.
        You can make a write access by redirection to the file and a sync command.


5. Check the result
   
   Check the result caused by the fault injection and stop the script.
   If the fault is successfully injected, the script prints the message
   beginning with "scsi_decide_disposition" or "scsi_add_timer" depending 
   on the fault type. 
   The "read/write error response" type of fault scripts (disk_rwerr.stp, 
   disk_rerr.stp, sector_rerr.stp,  temporary_rerr.stp, temporary_werr.stp) 
   will show "scsi_decide_disposition ..." on successfully injected faults.
   The "no response" type of fault scripts (r_timeout.stp, w_timeout.stp, rw_timeout.stp)
   will show "scsi_add_timer ..." on successfully injected faults

   The running SystemTap script can't stop automatically. So you need to 
   stop that by "Ctrl-C" or "pkill stap" command.


5. Scripts usage details
========================

SYNOPSIS
   stap <script name> major minor-min minor-max inode/LBAflag value -g -I <lib directory>


DESCRIPTION   
   Set up a hook to inject a given type of fault by using SystemTap
   Parameters as follows.

       script name: Particular type of fault
             major: Major number of the target device. Generally, 8 for HDD.
      　 minor-min: Minimum minor number of the target device candidate.
         minor-max: Maximum minor number of the target device candidate.
   inode/LBA flag : 0 or 1. 0 -"value" means LBA, 1- "value" means inode 
             value: inode or LBA value depends on "inode/LBA flag"

                    Note. LBA is not equal to a "block number" managed by a filesystem.
                          Block number is a logical location, but LBA is a physical 
                          location in the device.

     lib directory: Path to the common routine directory. 
                    You need to choose one of the following, depending on your environment.
                    fault_injection_common_scsi_RAID56  - target is SCSI disk using md RAID4/5/6
                    fault_injection_common_scsi         - target is SCSI disk otherwise
                    fault_injection_common_sata_RAID56  - target is SATA disk using md RAID4/5/6
                    fault_injection_common_sata         - target is SATA disk otherwise


  Rules about the range of target device:
   As described in the introduction, this tool is originally for a software RAID evaluation.
   Target device should be given as a range because the software raid does load balancing, 
   and the next access can't be predicted precisely.

   1. Target device candidates can be given by the range from minor-min to minor-max of the given
      major number. The minor numbers are used to distinguish physical disk.
      The first access within the range after SystemTap hook is ready,
      if the destination condition (given by LBA or inode number) met, the accessed 
      device will be the target device and the accessed sector will be the target sector. 
      The target sector and the target device never change until stopping the script.

      e.g.  When (major, minor-min, minor-max) = (8, 0, 49), sda, sdb, sdc, sdd will 
            be target candidates.

    2. Once the target device and the target sector is determined, fault injection
       will only occur on access to the target sector of the target device.

       This means that the "permanent" type of faults can only be injected repeatedly
       on access to the target sector of the target device. Other accesses complete 
       successfully.

    3. If you need to designate a particular target, you should give the same value to
       minor-min and minor-max.

    4. As described earlier, the minor-min and minor-max are used to distinguish physical disk.
       Each scripts can't distinguish disk partition by minor number in the same disk.
       e.g.  If (minor-max, minor-min) = (17, 18) given, it means that the target device 
             will be /dev/sdb.


EXAMPLES

  1. A temporary read error simulation

     #stap ./temporary_rerr.stp 8 1 17 1 5000747 -g -I ./fault_injection_common_sata/
     
     -> Set a temporary read error simulation hook to SCSI HDD(8) /dev/sda(1) or /dev/sdb(17).
        A read access to the file with inode 5000747 on sda or sdb will cause a read error.

  2. A read error correctable by write simulation

     #stap ./sector_rerr.stp 8 33 49 0 40496541 -g -I ./fault_injection_common_scsi/

     -> Set a correctable read error simulation hook to SCSI HDD(8) /dev/sdc(33) or /dev/sdd(49).
        This case the target sector is given by (0, 40496541), means LBA 40496541.
        A read access to one of these disks of LBA=40496541 will cause a read error.
        After read error injected to the LAB=40496541, a write access to the LAB=40496541
        assumed to fix the error. Then, following any access to LBA=40496541 will
        complete successfully.

6. Known Issues and limitations
================================

 - The read and write to inject a fault should be a "mapped" access.
   Direct I/O is not supported yet.

 - Currently run on  x86 architecture.

 
===============================================================================


Appendix A.

Preparing for using systemtap on Fedora8
------------------------------------------
  1. Decompress kernel and move them to an arbitrary location.
     # tar jxf linux-2.6.23.12.tar.bz2

  2. Some setting to compile the kernel

    At least, the following configuration is needed. 

    Loadable module support
     Enable loadable module support [Y]
     Module unloading [Y]
    General setup
     Kernel->user space relay support [Y]
    Instrumentation Support
     Kprobes [Y]
    Kernel hacking
     Kernel debugging [Y]
     Compile the kernel with debug info [Y]

    But you can reuse Fedora's config file.

     # cd linux-2.6.23.12
     # make mrproper
     # cp /boot/config-2.6.23.1-42.fc8 .config
     # make oldconfig
     # make prepare

  3. Build the kernel
     # make -j 4 bzImage
     # make -j 4 modules

  4. Install the kernel
     # make modules_install
     # make install

  5. Create symlinks for SystemTap
     # mkdir -p /usr/lib/debug/lib/modules/2.6.23.12/
     # ln -s /lib/modules/2.6.23.12/kernel /usr/lib/debug/lib/modules/2.6.23.12/
     # ln -s /lib/modules/2.6.23.12/build/vmlinux /usr/lib/debug/lib/modules/2.6.23.12/

  6. reboot the system to boot the new kernel.




