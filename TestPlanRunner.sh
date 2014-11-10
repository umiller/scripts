#!/bin/bash 
PBE=172.20.37.172
STEP=1
scriptName="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
exitCode=0
start_time=`date +%s`

function usage {
 echo "Default backend PBE server : $PBE"
        echo "Usage: $scriptName [Test Plan File] [print]optional"
		exit 1
	}


function pause {

read -n1 -r -p "Press any key to continue ..." </dev/tty
if [ $? -eq 0 ]; then
echo
else
echo

fi



}


if [[ "$1" != "" ]]
 then 	if [ ! -f $1 ]
		then
		echo "Test file $1 does not exist - aborting!!"
		exit 1
		fi
  else 
	usage
	exit 1
	fi

if [[ "$2" == "print" ]]
 then   
                verbose=TRUE
                fi
        
if [[ "$2" == "pause" || "$3" == "pause" ]]
	then
	isPause=TRUE
	fi



testFile=$1

input=$testFile

while IFS=, read TEST_DESCRIPTION TEST_PARAMS PASS_FACTOR TEST_TYPE
do
./TestSelector.sh $TEST_PARAMS >.testResults.$testFile.step$STEP
if [[ "$PASS_FACTOR" == "PASS_ALWAYS" ]]
	then testResult=PASSED
	else
	testResult=`grep $PASS_FACTOR .testResults.$testFile.step$STEP > /dev/null  && echo "PASSED" || echo FAILED`
fi

if [[ $verbose == "TRUE" ]]; then
echo "================ [Sending XML] ====================================================="
 cat .temp.xml
echo "===================================================================================="
fi
if [[ $verbose == "TRUE" ]]; then echo "******************************************************************************************************";fi
echo "Step $STEP : $TEST_DESCRIPTION [$testResult]"
if [[ $verbose == "TRUE" ]]; then echo "******************************************************************************************************";fi
if [[ $verbose == "TRUE" ]]
	then
	cat .testResults.$testFile.step$STEP
fi

if [[ "$TEST_TYPE" == "CRITICAL" && "$testResult" == "FAILED" ]]
	then
	echo "Critical step failed, abort test !!"
	echo
        echo "=== File $testFile : TEST FAILED ==="
	exit 1
fi
if [[ "$testResult" == "FAILED" ]]
	then
	exitCode=1;
fi
STEP=$((STEP+1))
if [[ "$isPause" == "TRUE" ]]
	then
	pause
	fi
done < "$input"
if [[ "$exitCode" == 0 ]]
	then
		echo
		echo "=== File $testFile : TEST PASSED SUCCESSFULLY ==="
		echo
	else
		echo
		echo "=== File $testFile : TEST FAILED ==="
		echo
fi
end_time=`date +%s`
time_elapsed=$(($end_time-$start_time))
echo "Execution time : $time_elapsed seconds."
exit $exitCode
