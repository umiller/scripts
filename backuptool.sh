#!/bin/bash 

##############################################################
## BACKUP / RESTORE Tool for IDT                            ##
##############################################################




function checkMandatory {

if [[ "$command" != "backup" && "$command" != "restore" ]]; then
		echo -e "$redColor--command is mandatory"
		isExit="TRUE"
fi
 
if [[ "$command" == "backup" && "$pathList" == "" && "$backupDescriptor" == "" ]] ; then
		echo -e "$redColor--pathList or --backupDescriptor is mandatory"
		isExit="TRUE"
fi
 
if [[ "$command" == "backup" &&  "$pathList" != "" && "$backupDescriptor" != "" ]] ;then
		echo -e "$redColor--pathList and --backupDescriptor cannot be set together on backup"
		isExit="TRUE"
fi

if [[ "$backupDescriptor" == "" && "$label" == "" ]] ;	then
		echo -e "$redColor--label is mandatory"
		isExit="TRUE"
fi

if [[ "$backupDescriptor" == "" && "$version" == "" ]] ;then
		echo -e "$redColor--version is mandatory"
		isExit="TRUE"
fi

if [[ "$backupDescriptor" == "" && "$backupDir" == "" ]] ;then
		echo -e "$redColor--backupDir is mandatory"
		isExit="TRUE"
fi

if [[ "$forceOverwrite" != "true" && "$forceOverwrite" != "false" ]] ;then
		echo -e "$redColor--forceOverwrite is mandatory"
		isExit="TRUE"
fi


if [[ "$isExit" == "TRUE" ]] ;	then
		echo -e "$resetColor"
		usage
		exit 1
fi
}

function usage {
        echo -e "$whiteColor$boldColor Usage: $boldColor$scriptName $greenColor[OPTION]$whiteColor$boldColor"
		echo -e " Backup / Restore tool for IDT$resetColor"
		echo -e ""
		echo -e "$greenColor      --command    $whiteColor       Mode of operation. command can be $greenColor[backup]$whiteColor or $greenColor[restore]"
		echo -e "$greenColor      --label      $whiteColor       Backup or restore label (i.e. component) - will be used in filename"
		echo -e "$greenColor      --version    $whiteColor       Defines the version of the backup set. (mandatory for both backup and restore)"
		echo -e "$greenColor      --pathList   $whiteColor       One or more path(s) or file(s) to backup (used only with backup,"
		echo -e "$greenColor                   $whiteColor       cannot be set together with backupDescriptor)"
		echo -e "$greenColor      --backupDescriptor $whiteColor External file with list of one or more path(s) to backup"
		echo -e "$greenColor                   $whiteColor       (used only with backup, cannot be set together with pathList)"
		echo -e "$greenColor      --backupDir  $whiteColor       Backup directory - location for both backups and restores"
		echo -e "$greenColor      --hostLabel  $whiteColor       (optional) Hostname label to determine backup location"
		echo -e "$greenColor      --excludeList$whiteColor       One or more path(s) or file(s) to exclude from backup (used only with backup,"
		echo -e "$greenColor                   $whiteColor       cannot be set together with backupDescriptor)"
		echo -e "$greenColor                   $whiteColor       (i.e. host or node - Default is local hostname = `hostname`)"
		echo -e "$greenColor      --forceOverwrite  $whiteColor  (optional) value can be $greenColor[true]$whiteColor or $greenColor[false]$whiteColor."
		echo -e "$greenColor                   $whiteColor       Determine if backup will overwrite in case it exists, default=[false]"
		echo -e "$greenColor      --colorMode  $whiteColor       (optional) value can be $greenColor[true]$whiteColor or $greenColor[false]$whiteColor, default=[true]"
		echo -e "$resetColor"
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



	
function runCommand {	


case "$command" in
        backup)
				if [[ "$backupDescriptor" != "" ]]; then
					descriptorValidator
				fi
				displayParameters
			backup
            ;;

        restore)
				if [[ "$backupDescriptor" != "" ]]; then
					descriptorValidator
				fi
				displayParameters
			restore
			
            ;;
		 
        *)
            echo -e "$redColor** ERROR command [$command] is not supported yet$resetColor"
            exit 1
 
esac

}
function displayParameters {


echo "====[IDT Backup\Restore tool]===="
echo "[Tool mode=$command]"
echo "[hostLabel=$hostLabel]"
echo "[$command label=$label]"
echo "[version=$version]" 
if [[ "$command" == "backup" ]];then echo "[pathList=$pathList]";fi
echo "[backupDescriptor=$backupDescriptor]"
echo "[forceOverwrite=$forceOverwrite]"
echo "[excludeList=$excludeList]"
echo ""
}

function descriptorValidator {
if [ ! -f $backupDescriptor ];then
	echo -e "(25) $redColor** ERROR Backup descriptor file $backupDescriptor not found! quitting...$resetColor"
	exit 25
fi
. $backupDescriptor 
commandResult=`echo $?`
if [[ "$commandResult" != "0" ]]; then
echo -e "($commandResult) $redColor** ERROR - loading descriptor file failed! check syntax. quitting...$resetColor"
exit $commandResult
fi

}



function backup {
start_time=`date +%s`
backupFileName=$backupDir/backup-$label-$hostLabel-$version.tar.gz
echo Building backup file name [$backupFileName]
	if [ -f $backupFileName ]; then
	echo -e "$greenColor** WARNING Backup file already exist$resetColor"
		if [[ "$forceOverwrite" == "false" ]]; then
		echo -e "(30) forceOverwrite is $greenColor[$forceOverwrite]$resetColor - quitting..."
		exit 30
		fi
	echo "forceOverwrite is [$forceOverwrite] - backup file will be overwrite"
	fi
checkTargetDirs
echo Checking if target directory exist
if [ ! -d $backupDir ]; then
echo "Backup directory [$backupDir] does not exist, creating..."
mkdir -p $backupDir
fi
echo Checking if backup file already exist on target [$backupDir]

calculateBackupSize
echo "Starting backup ..."
backupOnBackground

if [[ "$commandResult" != "0" ]]; then
echo -e "($commandResult) $redColor** ERROR - backup process failed with error $commandResult (tar error), deleting file $backupFileName and quitting...$resetColor"
rm -f $backupFileName
exit $commandResult
fi

backupFileSize=`ls -ltrh $backupFileName | awk '{print $5}'`
echo Backup completed successfully - File size is $backupFileSize
end_time=`date +%s`
time_elapsed=$(($end_time-$start_time))
echo "Total $command time : $time_elapsed seconds."

}

function restore {
start_time=`date +%s`
backupFileName=$backupDir/backup-$label-$hostLabel-$version.tar.gz
echo "Backup file: [$backupFileName]"
printf "Checking if backup exists ... "
if [ ! -f $backupFileName ]; then
printf " not found!\n"
echo -e "(10) $redColor** ERROR backup file $backupFileName was not found! quitting...$resetColor"
exit 10
fi
printf " found!\n"
printf "Calculating space needed to restore backup ..."
spaceNeeded=$((`gzip -l $backupFileName |tail -1|awk '{print $2}'` / 1024))
printf "[done]\n"
printf "calculating available disk space on target directory..."
diskSpace=`df -k $backupDir|tail -1|awk '{print $3}'`
printf "[done]\n"
echo "Total space needed for restore is `printf "%'d\n" $spaceNeeded` KB, available disk space `printf "%'d\n" $diskSpace` KB"
if [ $spaceNeeded -gt $diskSpace ];then
echo -e "(31) $redColor** ERROR no enough disk space for restore! quitting...$resetColor"
exit 31
fi
restoreOnBackground
if [[ "$commandResult" != "0" ]]; then
echo -e "($commandResult) $redColor** ERROR - restore process failed with error $commandResult (tar error) quitting...$resetColor"
exit $commandResult
fi
end_time=`date +%s`
time_elapsed=$(($end_time-$start_time))
echo "$command completed successfully, total time : $time_elapsed seconds."
return
}



function calculateBackupSize {
printf "calculating max backup size..."
maxBackupSize=`du -cs $pathList|tail -1|awk '{print $1}'`
printf "[done]\n"
printf "calculating available disk space on target directory..."
diskSpace=`df -k $backupDir|tail -1|awk '{print $3}'`
printf "[done]\n"
echo "Total space needed for backup is `printf "%'d\n" $maxBackupSize` KB, available space on target directory [$backupDir] is `printf "%'d\n" $diskSpace` KB"
if [ $maxBackupSize -gt $diskSpace ];then
echo -e "(40) $redColor** ERROR no enough disk space for backup! quitting...$resetColor"
exit 40
fi
return
}

function checkFreeSpace {
return
}

function backupOnBackground {
trap 'echo -e "\nKill signal detected - Removing backup file $backupFileName and shutting down background activity - PID:$pid";kill -9 $pid >> /dev/null 2&>1;rm -f $backupFileName;exit 200' SIGINT SIGTERM
dotNum=0
tar cfpPz $backupFileName $pathList &
pid=$!
while sleep 1; do
isProcessRunning=`ps |grep "$pid " > /dev/null  && echo "TRUE" || echo "FALSE"` 
if [[ "$isProcessRunning" == "FALSE" ]]; then
wait $pid
commandResult=`echo $?`
break
fi
printf "."
(( dotNum++ ))
	if [ $dotNum -eq 5 ]; then
		backupFileSize=`ls -ltrh $backupFileName | awk '{print $5}'`
		printf "[$backupFileSize]"
		dotNum=0
	fi
done
printf "[DONE]\n"


}

function restoreOnBackground {
trap 'echo "Kill signal detected - shutting down background activity - PID:$pid";kill -9 $pid >> /dev/null 2&>1;exit 200' SIGINT SIGTERM
echo "Start restoring ..."
commandResult=`echo $?`

dotNum=0
dotLine=1
tar xfpPz $backupFileName &
pid=$!
while sleep 1; do
	isProcessRunning=`ps |grep "$pid " > /dev/null  && echo "TRUE" || echo "FALSE"` 
	if [[ "$isProcessRunning" == "FALSE" ]]; then
		wait $pid
		commandResult=`echo $?`
		break
	fi
	printf "."
	(( dotNum++ ))
	if [ $dotNum -eq $dotLine ]; then
		#printf "\n"
		(( dotLine++ ))
		if [ $dotLine -eq 10 ]; then
			dotLine=1
		fi
		dotNum=0
	fi
	
done
printf "[DONE]\n"
}





function checkTargetDirs {
echo screening unexisting filenames and directories from pathList...
screenedItems=0
verifiedList=()
verifiedListString=""
IFS=' ' read -a array <<< "$pathList"
for path in "${array[@]}";do
	if [ -d $path ] || [ -f $path ]; then
	verifiedList+=($path)
		verifiedListString="$path $verifiedListString"
		verifiedListString=`echo $verifiedListString | sed -e 's/ *$//'`

	else
		echo "** WARNING $path does not exist! screening from pathList"
		(( screenedItems++ ))
	fi
done

arraySize=${#verifiedList[@]}
if [ $arraySize -lt 1 ];then
echo -e "(26) $redColor** ERROR there is nothing left to backup! quitting ...$resetColor"
exit 26
fi
if [ $screenedItems -eq 0 ];then
	echo "All item(s) exist. noting to screen"
else
let "totalItems=screenedItems+arraySize"
	echo "[$screenedItems/$totalItems] Items were screened from pathList"
fi

	pathList=$verifiedListString
echo New pathList = [$pathList]

return
}

function isColorSupport {

if [[ "$colorMode" != "false" ]];then
	boldColor="\e[1m"
	greenColor="\033[1;32m"
	redColor="\033[1;31m"
	whiteColor="\033[0;37m"
	resetColor="\033[0;00m"
else
	boldColor=""
	greenColor=""
	redColor=""
	whiteColor=""
	resetColor=""
fi

}

scriptName="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
colorSupport=`tput colors`
pathList=""
label=""
version=""
backupDescriptor=""
command=""
hostLabel=`hostname`
forceOverwrite="false"
OPTS=`getopt -o axby -l backupDir:,label:,forceOverwrite:,hostLabel:,version:,pathList:,backupDescriptor:,command:,colorMode:,excludeList: -- "$@"`

if [ $? != 0 ]
then
	echo "Syntax Error"
fi

#####


eval set -- "$OPTS"
while true ; do
    case "$1" in
        --backupDir) backupDir=$2; shift 2;;
		--label) label=$2; shift 2;;
		--hostLabel) hostLabel=$2; shift 2;;
        --version) version=$2; shift 2;;
        --pathList) pathList=$2; shift 2;;
        --backupDescriptor) backupDescriptor=$2; shift 2;;
		--forceOverwrite) forceOverwrite=$2; shift 2;;
		--excludeList) excludeList=$2; shift 2;;
        --command) command=$2; shift 2;;
        --colorMode) colorMode=$2; shift 2;;
		
 --) shift; break;;
    esac
done


isColorSupport
checkMandatory
runCommand
exit 
