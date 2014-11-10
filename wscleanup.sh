#!/bin/bash



function progress()
{
   sleep 1 
   while true
  do
  
      echo -n "."
    sleep 1
  done
}  
function diskSpace
{
local kbSpace=`df -k ./|tail -1|awk '{print $3}'`
space=$kbSpace
allignedSpace=`printf "%'d\n" $space`
}

function cleanUpOnBreak
{
echo -e "\n** WARNING Kill signal detected."
echo "Total files deleted : $filesDeletedCounter"

diskSpace
spaceAtEnd=$space
freedSpace=$((spaceAtEnd-spaceAtStart))
echo "Total space freed `printf "%'d\n" $freedSpace` KB"
end_time=`date +%s`
time_elapsed=$(($end_time-$start_time))
echo "Total time : $time_elapsed sec"

#kill -9 $pidProgress >> /dev/null 2&>1
exit 200
}

function detectProfiles
{
local dirCounter
profilesArray=()
for dir in $(find $profilesDir/* -maxdepth 0 -type d)
do
profilesArray+=($dir)

  (( dirCounter++ ))
done
echo "Total $dirCounter profiles detected"
echo "Profile(s) detected:"
printf -- '[%s]\n' "${profilesArray[@]}"


}

start_time=0
elapsed_time=0
profilesDir="/opt/IBM/WebSphere/AppServer/profiles"
targetDirectory="/opt/IBM/WebSphere/AppServer/profiles/*/wstemp/*"
daysToLive=3
filesDeletedCounter=0
dotNum=0
diskSpace
spaceAtStart=$space
detectProfiles
echo "Available disk space is $allignedSpace KB"
#progress &
pidProgress=$!
start_time=`date +%s`
isPrintDot=$start_time
isPrintFilesDeleted=$start_time
	for profile in "${profilesArray[@]}";do
		if [ -d $profile/wstemp ]; then
			echo "Start working on profile $profile..."
			echo "Removing files older than $daysToLive days..."
			find $profile/wstemp/* -type f -mtime +$daysToLive| while read file; do
				trap cleanUpOnBreak SIGHUP SIGINT SIGTERM  
				(( filesDeletedCounter++ ))
				rm $file
					if  [[ "$isPrintDot" != "`date +%s`" ]]; then 
						isPrintDot="`date +%s`"
						printf ".[$filesDeletedCounter]."
					fi
				#sleep 1
			done
			echo -e "\nNow removing empty directories..."
			find $profile/wstemp/* -depth -empty -delete
		fi
	done

diskSpace
spaceAtEnd=$space
echo -e "\nAvailable disk space is $allignedSpace KB"
#Disabled untill this problem will be fixed (filesDeletedCounter=0
#echo "Total files deleted $filesDeletedCounter"

freedSpace=$((spaceAtEnd-spaceAtStart))
echo "Total space freed `printf "%'d\n" $freedSpace` KB"
end_time=`date +%s`
time_elapsed=$((end_time-start_time))
echo "Total time : $time_elapsed sec"
echo ""
#kill -9 $pidProgress  > /dev/null 2&>1

