#!/bin/bash

#
# Befor running this script, you need /dev/sdb1, /dev/sdc1, /dev/sdd1, /dev/sde1
# partitions with ID = 0xfd (Linux raid). They must be the same size.
#


GREPRESULT=0
RESULT=1
MDDEV=/dev/mdx
RAIDTYPE=$1
RAIDENV=$2

echo "create an array"


case $RAIDTYPE in
    "1") mdadm -C /dev/md0 --assume-clean -R -l1 -n2 /dev/sd[bc]1; RESULT=$?; MDDEV=/dev/md0;;
    "10") mdadm -C /dev/md0 --assume-clean -R -l10 -n4 /dev/sd[bcde]1; RESULT=$?; MDDEV=/dev/md0;;
    *) echo "illeagal request"; exit;
esac

# if raid array created, wait for initialization.
if [ $RESULT -eq 0 ]; then

    while [ $GREPRESULT -eq 0 ]
    do
       cat /proc/mdstat | grep "resync" > /dev/null
       GREPRESULT=$?
    done

    echo "resync done"
    # create ext3 filesystem on the RAID device
    mkfs -t ext3 $MDDEV
    sleep 3
fi


case $RAIDENV in
    "norm") ;;
    "red") mdadm /dev/md0 -a  /dev/sdd1 || mdadm /dev/md0 -a  /dev/sdf1;;
    "deg" | "recov") mdadm /dev/md0 -f /dev/sdb1;  \
           sleep 1; \
           mdadm /dev/md0 -f /dev/sde1; \
           sleep 1;;
    *) echo "illeagal request"; exit;
esac

sleep 1

# show the md status
cat /proc/mdstat

