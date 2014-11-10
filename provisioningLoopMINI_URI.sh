echo Starting PBE Provisioning loop on ENV MINI_URI, Press  CTRL+C to Abort...
echo
while true
do
echo starting provisioning test at `date`
echo Starting Blade: ap0tv01ras02pbsw0
echo =================================
for x in `ls ap0tv01ras02pbsw0v*`; do ./TestPlanRunner.sh $x  ; done|grep "==="
echo 10 Seconds delay ...
echo
sleep 10
done
