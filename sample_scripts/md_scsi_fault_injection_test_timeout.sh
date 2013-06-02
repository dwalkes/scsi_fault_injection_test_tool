#!/bin/bash

DISKTYPE=$1
RAIDLEVEL=$2
FILENAME=0
DIRNAME='results_'$(date --rfc-3339=date)_timeout

mkdir ./$DIRNAME

#echo $tempresult
grep read scsi_fault_injection_scripts.txt | cut -f 2 > readscripts
grep write scsi_fault_injection_scripts.txt | cut -f 2 > writescripts


    echo "####"
    echo "raid $RAIDLEVEL"
    echo "####"

    for env in norm red deg recov
    do
        echo "raid $RAIDLEVEL status $env"

        echo "        read timeout"
            date
            echo "*"
            echo "*  r_timeout.stp on RAID$RAIDLEVEL $env condition"
            echo "*"
            FILENAME="$DISKTYPE-RAID$RAIDLEVEL-$env-r_timeout"       
            sh md_rerr_test_sample.sh $DISKTYPE $RAIDLEVEL $env r_timeout.stp > ./$DIRNAME/$FILENAME.result


        echo "        write timeout"
            date
            echo "*"
            echo "*  w_timeout.stp on RAID$RAIDLEVEL $env condition"
            echo "*"
            FILENAME="$DISKTYPE-RAID$RAIDLEVEL-$env-w_timeout"       
            sh md_werr_test_sample.sh $DISKTYPE $RAIDLEVEL $env w_timeout.stp > ./$DIRNAME/$FILENAME.result
    done

rm readscripts
rm writescripts
rm stapresult.txt

