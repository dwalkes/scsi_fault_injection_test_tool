#!/bin/bash

#
GREPRESULT=1
TESTDIR=/home/test
TOOLDIR=".."
TARGETINODE=0
DEVTYPE=$1
RAIDTYPE=$2
RAIDENV=$3
SCRIPTNAME=$4
RAIDDEV=/dev/md0
TESTFILENAME='targetfile_'$(date --rfc-3339=date)
TARGETDEVS="8 16 81"

if [ $RAIDENV = "recov" ]; then
    TARGETDEVS="8 33 81"
fi


if [ -z "$DEVTYPE" -o -z "$RAIDTYPE" -o -z "$SCRIPTNAME" ]; then
    echo "usage: sh $0 device(scsi or sata) raid(1 or 10) env scriptname"
    echo "       e.g. sh $0 scsi 1 deg disk_rerr.stp"
    exit
fi

if [ $RAIDTYPE -ne 1 -a $RAIDTYPE -ne 10 ]; then
    echo "usage: sh $0 device(scsi or sata) raid(1 or 10)"
    echo "       e.g. sh $0 scsi 1"
    exit
fi



# cleanup
umount $TESTDIR
mdadm -S $RAIDDEV
mkdir /home/test

# create an array to be tested
    echo "#############################"
    echo "# "
    echo "#     Creating an array"
    echo "# "
    echo "#############################"
sh ./md_create_array.sh $RAIDTYPE $RAIDENV

# mount md array
mount -t ext3 $RAIDDEV $TESTDIR
sleep 5

# create a target file for a fault injection and get its inode num
dd if=/dev/urandom of=$TESTDIR/targetfile bs=1000 count=1000
cp $TESTDIR/targetfile /tmp/$TESTFILENAME
echo "test write" >> /tmp/$TESTFILENAME

echo "test file to inject a fault created"

TARGETINODE=$(ls -ail $TESTDIR | grep targetfile | awk '{print $1}')
echo "TARGETINODE= $TARGETINODE"

#
# main routine 
#
    sync
    ls $TESTDIR -hil

    # purge cache
    echo 1 > /proc/sys/vm/drop_caches;
    sleep 2
    cat $TESTDIR/targetfile > /dev/null

    # Run the script
    echo "#############################"
    echo "# "
    echo "#     Runing  $SCRIPTNAME "
    echo "# "
    echo "#############################"
    stap $TOOLDIR/$SCRIPTNAME $TARGETDEVS 1 $TARGETINODE -g -I $TOOLDIR/fault_injection_common_$DEVTYPE/ -v | tee stapresult.txt &

    echo "waiting stap startup"
    sleep 1
    GREPRESULT=1
    while [ $GREPRESULT -eq 1 ]
    do
       grep "BEGIN" stapresult.txt > /dev/null
       GREPRESULT=$?
    done

    if [ $RAIDENV = "recov" ]; then
        # recovering /dev/sdb1
        mdadm /dev/md0 -r /dev/sdb1
        sleep 1
        mdadm /dev/md0 -a /dev/sdb1
        sleep 1
        cat /proc/mdstat
    fi

    echo "#############################"
    echo "# "
    echo "#     Injecting a fault "
    echo "# "
    echo "#############################"
    date
    sleep 1
    # write to the test file
    echo "test write" >> $TESTDIR/targetfile
    sleep 1
    # sync command to start actual write
    sync
    echo "Fault injected"

    # stop the script
    pkill stap
    sleep 10

    # print the result, see also the script printout
    echo "#############################"
    echo "# "
    echo "#    After the fault injection. Show the results "
    echo "# "
    echo "#############################"
    sleep 5

# compare the original file with the read file
echo "verify the contents when a fault injected" 
sync
echo 1 > /proc/sys/vm/drop_caches;
cmp /tmp/$TESTFILENAME $TESTDIR/targetfile
echo "cmp result = $?"
tail -n 50 /var/log/messages
cat /proc/mdstat

# wait for recovery completion if needed
cat /proc/mdstat | grep "recovery" > /dev/null
GREPRESULT=$?
if [ $GREPRESULT -eq 0 ]; then
   
    while [ $GREPRESULT -eq 0 ]
    do
       cat /proc/mdstat | grep "recovery" > /dev/null
       GREPRESULT=$?
    done
echo "recovery done"
cat /proc/mdstat
fi

# cleanup
umount $RAIDDEV
umount /media/disk
mdadm -S $RAIDDEV
rm -rf /home/test

