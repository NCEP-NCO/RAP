set -x

##############################

export BASE=`pwd`
cd $BASE

source $BASE/build_rap_module_load.sh

cd ${BASE}/rap_process_cloud.fd
make clean
make

##############################
