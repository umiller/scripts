#!/bin/bash 
\mkdir test_results_archives > /dev/null 2>&1
\rm batch_process_pass.log > /dev/null 2>&1
\rm batch_process_fail.log > /dev/null 2>&1

PBE=`hostname`



STEP=1
scriptName="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
exitCode=0
start_time=`date +%s`

function usage {
 #echo "Default backend PBE server : $PBE"
        echo "Usage: $scriptName [Test Plan File] [Servers File] [MSISDN start] [Number of subscribers in the batch]"
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



#Arguments assignments

testFile=$1
serverFile=$2
MSISDN=$3
COUNTER=$4

#Servers array initilize
serverIndex=0

input=$serverFile
while IFS=, read SERVER
do
serverArray[$serverIndex]=$SERVER

((serverIndex++))

done < "$input"
arrayLength=$serverIndex
serverIndex=0;

for (( c=1; c<=$COUNTER; c++ ))

do



input=$testFile

while IFS=, read TEST_DESCRIPTION TEST_PARAMS PASS_FACTOR TEST_TYPE
do
./TestSelector.sh $TEST_PARAMS --sourceMSISDN $MSISDN --server ${serverArray[$serverIndex]}  >.testResults.$testFile.step$STEP
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
#echo "Step $STEP : $TEST_DESCRIPTION [$testResult]"
if [[ $verbose == "TRUE" ]]; then echo "******************************************************************************************************";fi
if [[ $verbose == "TRUE" ]]
	then
	cat .testResults.$testFile.step$STEP
fi

if [[ "$TEST_TYPE" == "CRITICAL" && "$testResult" == "FAILED" ]]
	then
	echo "Critical step failed, abort test !!"
        echo "=== MSISDN - $MSISDN , File $testFile : TEST FAILED ==="
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
		echo "=== MSISDN - $MSISDN , server ${serverArray[$serverIndex]} , File $testFile : TEST PASSED SUCCESSFULLY ==="
		echo $MSISDN >> batch_process_pass.log
	else
		echo "=== MSISDN - $MSISDN , server ${serverArray[$serverIndex]} , File $testFile : TEST FAILED ==="
		echo $MSISDN >> batch_process_fail.log
fi
((MSISDN++))
((serverIndex++))
if [[ $serverIndex == $arrayLength ]]
	then
		serverIndex=0
fi
done

end_time=`date +%s`
time_elapsed=$(($end_time-$start_time))
echo "Execution time : $time_elapsed seconds."
echo Archiving test results ...
zip test_results_archives/testResults-$testFile-`date +%d-%m-%Y-%H.%M.%S`.zip .testResults.$testFile.step* batch_process_pass.log batch_process_fail.log > /dev/null 2>&1 && echo "Archive created successfully" || echo Archive failed !!
\rm batch_process_pass.log batch_process_fail.log .testResults.$testFile.step* > /dev/null 2>&1
exit $exitCode


