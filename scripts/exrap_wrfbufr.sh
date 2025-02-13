#!/bin/ksh -l
################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         exrap_wrfbufr.ecf
# Script description:  Run rap wrfbufr jobs
#
# Author:      G Manikin / M Hu    EMC/GSD         Date: 2011-09-15
#
# Abstract: This script runs the RAP wrfbufr jobs for the 18-h RAP forecast
#
# Script history log:
# 2011-09-15  G Manikin / M Hu  -- new script 
# 2018-01-25  B Blake / C Guastini / G Manikin / C Alexander - RAPv4

set -xa
cd $DATA 

msg="$job HAS BEGUN"
postmsg $jlogfile "$msg"

# fhr is passed from the SMS script
fhr=$fhr

# Set up some constants
export XLFRTEOPTS="unit_vars=yes"
START_TIME=$PDY$cyc
echo $START_TIME >STARTTIME
export CORE=RAPR
export OUTTYP=netcdf

cp ${FIXrap}/rap_profdat .
OUTTYP=netcdf
model=RAPR
NFILE=1
INCR=01
CYCLE1=`$NDATE -1 $START_TIME`
date=`$NDATE $fhr $START_TIME`

wyr=`echo $date | cut -c1-4`
wmn=`echo $date | cut -c5-6`
wdy=`echo $date | cut -c7-8`
whr=`echo $date | cut -c9-10`

let fhrold="$fhr - 1"
dateold=`$NDATE $fhrold $START_TIME`

oyr=`echo $dateold | cut -c1-4`
omn=`echo $dateold | cut -c5-6`
ody=`echo $dateold | cut -c7-8`
ohr=`echo $dateold | cut -c9-10`

timeform=${wyr}"-"${wmn}"-"${wdy}"_"${whr}"_00_00"
timeformold=${oyr}"-"${omn}"-"${ody}"_"${ohr}"_00_00"


if [ $fhr -eq 0 ]; then
# Look back 3 hours for relevant file - if not found, we do not want to
# utilize information from an older cycle for hourly average fields
  counter=1
#  targetsize=6858968708
  targetsize=6854865028
  targetsize2=6871551620  ## rapv5 working dir on dell2
  while [[ $counter -lt 04 ]]; do
    counterhr=$counter
    typeset -Z2 counterhr
    CYC_TIME=`$NDATE -${counter} $dateold` 
    if [ -r ${RAPGES_FCYC}/rap_${CYC_TIME}f0$counterhr ]; then
      filesize=$(stat -c%s ${RAPGES_FCYC}/rap_${CYC_TIME}f0$counterhr)
      echo $filesize
#     if [ $filesize -eq $targetsize ]; then
      if [[ $filesize -eq $targetsize || $filesize -eq $targetsize2 ]]; then
      echo "Found rap_${CYC_TIME}f0$counterhr for $dateold"
      cp ${RAPGES_FCYC}/rap_${CYC_TIME}f0$counterhr ./wrfout_d01_${timeformold}
      break
      fi
    fi
    counter=` expr $counter + 1 `
  done
  if [ $counter -eq 04 ]; then
    echo "No file found for $dateold"
  fi
else
  cp ${INPUT_DATA}/wrfout_d01_${timeformold} wrfoutd01_${timeformold} 
fi

OLDOUTFIL=wrfoutd01_${timeformold}
time_analysis='00'

# use pre-DFI file for 00-hr data
if [ ${fhr} -eq ${time_analysis} ]; then
  fcstfile=${INPUT_DATA}/wrfinput_d01
  cp $fcstfile .
  OUTFIL=wrfinput_d01
else
  OUTFIL=wrfoutd01_${timeform}
  cp ${INPUT_DATA}/wrfout_d01_${timeform} wrfoutd01_${timeform}
fi

YYYY=`echo $PDY | cut -c1-4`
MM=`echo $PDY | cut -c5-6`
DD=`echo $PDY | cut -c7-8`
VALID_TIME=${YYYY}'-'${MM}'-'${DD}'_'${cyc}':00:00'

cat > itag <<EOF
$OUTFIL
$model
$OUTTYP
$VALID_TIME
$NFILE
$INCR
${fhr}
$OLDOUTFIL
EOF

rm -rf fort.19
rm -rf fort.11
ln -s itag              fort.11
ln -s $DATA/rap_profdat  fort.19
ln -s $DATA/profilm.c1.tm00 fort.79

#./startmsg

datestr=`date`
echo about to run program at $datestr

cp ${EXECrap}/rap_wrfbufr .
runline="mpiexec -n 1 -ppn 1 ./rap_wrfbufr"
$runline >> wrfbufr.out
export err=$?; err_chk

mv profilm.c1.tm00 profilm.c1.f${fhr}

echo EXITING $0
exit
