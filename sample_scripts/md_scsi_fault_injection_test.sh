#!/bin/bash

DISKTYPE=$1
RAIDLEVEL=$2
FILENAME=0
DIRNAME='results_'$(date --rfc-3339=date)

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

        echo "        read err"
        while read scriptname
        do
            date
            echo "*"
            echo "*  $scriptname on RAID$RAIDLEVEL $env condition"
            echo "*"
            FILENAME="$DISKTYPE-RAID$RAIDLEVEL-$env-$scriptname"       
            sh md_rerr_test_sample.sh $DISKTYPE $RAIDLEVEL $env $scriptname > ./$DIRNAME/$FILENAME.result
        done < readscripts

        echo "        write err"
        while read scriptname
        do
            date
            echo "*"
            echo "*  $scriptname on RAID$RAIDLEVEL $env condition"
            echo "*"
            FILENAME="$DISKTYPE-RAID$RAIDLEVEL-$env-$scriptname"       
            sh md_werr_test_sample.sh $DISKTYPE $RAIDLEVEL $env $scriptname > ./$DIRNAME/$FILENAME.result
        done < writescripts

    done

rm readscripts
rm writescripts
rm stapresult.txt
