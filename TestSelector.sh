#!/bin/bash 
PBE=172.20.37.38
PORT=9080
scriptName="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
TEMP=0
SOURCE_MSISDN=12120000000
TARGET_MSISDN=12120000001
SOURCE_SITE=SITE1

OPTS=`getopt -o axby -l server:,sourceMSISDN:,targetMSISDN:,jobID:,command:,port:,sourceSite:,targetSite: -- "$@"`
if [ $? != 0 ]
then
    exit 1
fi

eval set -- "$OPTS"

while true ; do
    case "$1" in
        -a) echo "Got a"; shift;;
        -b) echo "Got b"; shift;;
        -x) echo "Got x"; shift;;
        --sourceMSISDN) SOURCE_MSISDN=$2; shift 2;;
        --targetMSISDN) TARGET_MSISDN=$2; shift 2;;
        --server) PBE=$2; shift 2;;
        --jobID) jobID=$2; shift 2;;
        --command) COMMAND=$2; shift 2;;
        --port) PORT=$2; shift 2;;
        --sourceSite) SOURCE_SITE=$2; shift 2;;
        --targetSite) TARGET_SITE=$2; shift 2;;


        --) shift; break;;
    esac
done
#echo "Args:"
#for arg
#do
#    echo $arg
#done

function checkMandatory {
 if [[ "$COMMAND" != "activateICB" && "$COMMAND" != "getCopyProgress" &&  "$COMMAND" != "deleteBySite" &&  "$COMMAND" != "getBySite" &&  "$COMMAND" != "queryCount" && "$COMMAND" != "copy" && "$COMMAND" != "remove" && "$COMMAND" != "query" && "$COMMAND" != "isExist" && "$COMMAND" != "create" && "$COMMAND" != "delete" && "$COMMAND" != "update" && "$COMMAND" != "get" && "$COMMAND" != "getSites" && "$COMMAND" != "changeMSISDN" ]]
 
	then
	usage
fi
}

function usage {
        echo "Usage: $scriptName [OPTION]... [FILE]..."
		echo "Command line automation tool for BSS."
		echo ""
		echo "Mandatory arguments to long options are mandatory for short options too."
		echo "  -c, --command=COMMAND  COMMAND can be getSites, create, get, getBySite, delete, deleteBySite, isExist, edit, changeMSISDN, copy, getCopyProgress, remove, query, queryCount, activateICB."
		echo "  -m, --sourceMSISDN     MSISDN 10,11 or 12 digit format for MSISDN in case needed."
		echo "      --targetMSISDN     Target MSISDN 10,11 or 12 digit format for MSISDN in case needed for call diversions,"
		echo "      --sourceSite       Site name to run the test by Site in case needed."
		echo "      --targetSite       Target Site name to run the test in case needed."
		echo "                         Change MSISDN target etc ..."
		echo "  -s, --server           Server IP or full FQDN. [default $PBE]."
		echo "      --jobID            Job ID input for copy or remove operations. use jobID=last to use last copy \ remove operation"
		echo "      --port             PORT for connecting to server. [default $PORT]."
		echo "  -h, --help             This help screen."
		exit 1
	}

function checkFileExist {
if [ ! -f $1 ]
      then
      echo "file $1 does not exist - aborting!!"
      exit 1
fi
}
function checkConnectivity {
 if [[  "$1" != "" ]]

      then
        PBE=$1
	if ping -c1 -q $PBE > /dev/null; then TEMP=0 
	else
	echo No connection for $PBE .. - aborting!!
	exit 1
	fi
 fi
}

function replaceMSISDN1 {
eval sed -i -e 's/___MSISDN1___/$SOURCE_MSISDN/g' .temp.xml
}

function replaceMSISDN2 {
eval sed -i -e 's/___MSISDN2___/$TARGET_MSISDN/g' .temp.xml
}


function replaceSITE {
eval sed -i -e 's/___SITE___/$SOURCE_SITE/g' .temp.xml
}

function replaceTargetSITE {
eval sed -i -e 's/___TARGET_SITE___/$TARGET_SITE/g' .temp.xml
}


function POST {
curl -s http://$PBE:$PORT/xmlapi/v1/ -H "Content-Type: text/xml" -H "Authorization: Basic c25vb3BlcjpTTk9PUEVS" --data-binary "@.temp.xml"
}

function POSTQUERY {
curl -s http://$PBE:$PORT/pbe_data_migration/connector/$migrationCommand -H 'Content-Type: application/xml' -X PUT --data-binary "@.temp.xml" >.file.zip
FILESIZE=$(stat -c%s ".file.zip")
if [[ "$FILESIZE" == 0 ]];
        then
        echo ERROR Exporting $COMMAND result
        exit 2
fi
testExceptionResult=`grep "General Exception" .file.zip > /dev/null  && echo "PASSED" || echo FAILED`

if [[ "$testExceptionResult" == "PASSED" ]];
	then
	cat .file.zip
	echo ""
	exit 2
fi

queryResultFile=`unzip .file.zip|grep -o "query.*"`
cat $queryResultFile
\rm $queryResultFile >/dev/null
}


function POSTQUERYCOUNT {
curl -s http://$PBE:$PORT/pbe_data_migration/connector/$migrationCommand -H 'Content-Type: application/xml' -X PUT --data-binary "@.temp.xml"|sed -e 's,.*<countStr>\([^<]*\)</countStr>.*,\1,g' >.queryCountFile
FILESIZE=$(stat -c%s ".queryCountFile")
if [[ "$FILESIZE" == 0 ]];
        then
        echo ERROR Exporting $COMMAND result
        exit 2
fi
testExceptionResult=`grep "General Exception" .queryCountFile > /dev/null  && echo "PASSED" || echo FAILED`

if [[ "$testExceptionResult" == "PASSED" ]];
	then
	cat .queryCountFile
	echo ""
	exit 2
fi

queryResultFile=.queryCountFile
echo Total number of subscribers answer to query are `cat $queryResultFile`
\rm $queryResultFile >/dev/null
}

function GETCOPYPROGRESS {
if [[ $jobID == "" ]];
        then
                echo Missing Job id
                exit 1
        fi
if [[ $jobID == "last" ]];
        then
                jobID=`cat .copyFile`
        fi
		
PROGRESS=`curl -s http://$PBE:$PORT/pbe_data_migration/connector/getCopyProgress/$jobID -H 'Content-Type: application/xml'`
echo $PROGRESS >.progress_temp_file
testResult=`grep "was not found" .progress_temp_file > /dev/null  && echo "PASSED" || echo FAILED`
if [[ $testResult == "PASSED" ]];
        then
        echo transaction $1 were not found
        exit 1
fi

PERCENTAGE=`sed -e 's,.*<pollingProgress>\([^<]*\)</pollingProgress>.*,\1,g' .progress_temp_file`

while [[ $PERCENTAGE != "100" ]];
        do
                PROGRESS=`curl -s http://$PBE:$PORT/pbe_data_migration/connector/getCopyProgress/$jobID -H 'Content-Type: application/xml'`
                echo $PROGRESS >.progress_temp_file
                PERCENTAGE=`sed -e 's,.*<pollingProgress>\([^<]*\)</pollingProgress>.*,\1,g' .progress_temp_file`
                echo $PERCENTAGE% of job completed
                sleep 1
        done
SUCCESS_COUNT=`sed -e 's,.*<successCount>\([^<]*\)</successCount>.*,\1,g' .progress_temp_file`
TOTAL_COUNT=`sed -e 's,.*<totalCount>\([^<]*\)</totalCount>.*,\1,g' .progress_temp_file`
echo COPY Job finished !! Total subscribers in job $TOTAL_COUNT, Total subscribers succeeded $SUCCESS_COUNT
exit 0
}



function POSTMIGRATION {
COPYFILE=.copyFile
curl -s http://$PBE:$PORT/pbe_data_migration/connector/$migrationCommand -H 'Content-Type: application/xml' -X PUT --data-binary "@.temp.xml"|sed -e 's,.*<transactionId>\([^<]*\)</transactionId>.*,\1,g' >$COPYFILE
FILESIZE=$(stat -c%s "$COPYFILE")
if [[ "$FILESIZE" == 0 ]];
        then
        echo ERROR Exporting $COMMAND result
        exit 2
fi
testExceptionResult=`grep "General Exception" $COPYFILE > /dev/null  && echo "PASSED" || echo FAILED`

if [[ "$testExceptionResult" == "PASSED" ]];
	then
	cat $COPYFILE
	echo ""
	exit 2
fi

echo Job ID for $COMMAND is `cat $COPYFILE`
}


	
function runTest {	


case "$COMMAND" in
        getCopyProgress)
            testFile=createSubscriber.xml
			checkFileExist $testFile
			\cp $testFile .temp.xml > /dev/null
			GETCOPYPROGRESS
            ;;

        activateICB)
            testFile=activateICB.xml
			checkFileExist $testFile
			\cp $testFile .temp.xml > /dev/null
			replaceMSISDN1
			replaceSITE
			POST

            ;;

		create)
            testFile=createSubscriber.xml
			checkFileExist $testFile
			\cp $testFile .temp.xml > /dev/null
			replaceMSISDN1
			replaceSITE
			POST

            ;;

        copy)
            testFile=copySubscriber.xml
			checkFileExist $testFile
			\cp $testFile .temp.xml > /dev/null
			replaceMSISDN1
			replaceTargetSITE
			migrationCommand=copy
			POSTMIGRATION

            ;;
        remove)
            testFile=removeSubscriber.xml
			checkFileExist $testFile
			\cp $testFile .temp.xml > /dev/null
			replaceMSISDN1
			replaceSITE
			migrationCommand=remove
			POSTMIGRATION

            ;;
        query)
            testFile=querySubscriber.xml
			checkFileExist $testFile
			\cp $testFile .temp.xml > /dev/null
			replaceMSISDN1
			replaceMSISDN2
			migrationCommand=getQueryZip
			POSTQUERY

            ;;

		queryCount)
            testFile=querySubscriber.xml
			checkFileExist $testFile
			\cp $testFile .temp.xml > /dev/null
			replaceMSISDN1
			replaceMSISDN2
			migrationCommand=queryCount
			POSTQUERYCOUNT

            ;;

			
        delete)
            testFile=deleteSubscriber.xml
			checkFileExist $testFile
			\cp $testFile .temp.xml > /dev/null
			replaceMSISDN1
			replaceSITE
			POST
            ;;

        deleteBySite)
            testFile=deleteSubscriberBySite.xml
			checkFileExist $testFile
			\cp $testFile .temp.xml > /dev/null
			replaceMSISDN1
			replaceSITE
			POST
            ;;
			
			
		changeMSISDN)
            testFile=changeMSISDN.xml
			checkFileExist $testFile
			\cp $testFile .temp.xml > /dev/null
			replaceMSISDN1
			replaceMSISDN2
			replaceSITE
			POST
            ;;
         
        update)
            testFile=updateSubscriber.xml
			checkFileExist $testFile
			\cp $testFile .temp.xml > /dev/null
			replaceMSISDN1
			replaceMSISDN2
			replaceSITE
			POST
            ;;
        getSites)
            testFile=getSites.xml
			checkFileExist $testFile
			\cp $testFile .temp.xml > /dev/null
			POST
            ;;
       isExist)
            testFile=getSubscriber.xml
			checkFileExist $testFile
			\cp $testFile .temp.xml > /dev/null
			replaceMSISDN1
			replaceSITE
			POST > .isExist.tmp						
			isExistResult=`grep "tasGetSubscriberResponse" .isExist.tmp > /dev/null  && echo "___TRUE___" || echo "___FALSE___"`
			echo $isExistResult
            ;;			
        get)
            testFile=getSubscriber.xml
			checkFileExist $testFile
			\cp $testFile .temp.xml > /dev/null
			replaceMSISDN1
			replaceSITE
			POST
            
            ;;
         
        getBySite)
            testFile=getSubscriberBySite.xml
			checkFileExist $testFile
			\cp $testFile .temp.xml > /dev/null
			replaceMSISDN1
			replaceSITE
			POST
            
            ;;
		 
		 
        *)
            echo $"ERROR!!"
            exit 1
 
esac

}

## check if all mandatory args has been defined
checkMandatory
checkConnectivity $PBE
runTest
