echo " MINI_URI ENVIRONMENT CCM Tester script `date` "
echo ==================================================================
wget -qO- http://ap0tv01ras03ndsw0v1:9080/topology/management/find/cage/fake |grep "[ ]" >/dev/null && echo CCM ap0tv01ras03ndsw0v1:9080 PASSSED || echo CCM ap0tv01ras03ndsw0v1:9080 FAILED
