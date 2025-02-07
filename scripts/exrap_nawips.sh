#!/bin/ksh
###################################################################
echo "----------------------------------------------------"
echo "exnawips - convert NCEP GRIB files into GEMPAK Grids"
echo "----------------------------------------------------"
echo "History: Mar 2000 - First implementation of this new script."
echo "S Lilly: May 2008 - add logic to make sure that all of the "
echo "                    data produced from the restricted ECMWF"
echo "                    data on the CCS is properly protected."
#####################################################################

set -xa

msg="Begin job for $job"
postmsg "$jlogfile" "$msg"

export RUN=$1
export GRIB=$2
export DBN_ALERT_TYPE=$3
export EXT=$4

export 'PS4=$RUN:$SECONDS + '

mkdir $DATA/$RUN
cd $DATA/$RUN

cp $GEMPAKrap/fix/g2varsncep1.tbl .
cp $GEMPAKrap/fix/g2vcrdncep1.tbl .
cp $GEMPAKrap/fix/g2varswmo2.tbl .
cp $GEMPAKrap/fix/g2vcrdwmo2.tbl .

#
NAGRIB=nagrib2
#

cpyfil=gds
garea=dset
gbtbls=
maxgrd=4999
kxky=
grdarea=
proj=
output=T
pdsext=no

maxtries=180
fhcnt=$fstart
while [ $fhcnt -le $fend ] ; do
  if [ $fhcnt -ge 100 ] ; then
    typeset -Z3 fhr
  else
    typeset -Z2 fhr
  fi
  fhr=$fhcnt

  fhr3=$fhcnt
  typeset -Z3 fhr3
  GRIBIN=$COMIN/${model}.${cycle}.${GRIB}${fhr}${EXT}
  GEMGRD=${RUN}_${PDY}${cyc}f${fhr3}
  GRIBIN_chk=$GRIBIN.idx

  icnt=1
  while [ $icnt -lt 1000 ]
  do
    if [ -r $GRIBIN_chk ] ; then
      sleep 10                               # sleep 10 to avoid GRIBIN is not ready
      break
    else
      let "icnt=icnt+1"
      sleep 20
    fi
    if [ $icnt -ge $maxtries ]
    then
      msg="FATAL ERROR: ABORTING after 1 hour of waiting for F$fhr to end."
      err_exit $msg
    fi
  done

  cp $GRIBIN grib$fhr

  startmsg

  $GEMEXE/$NAGRIB << EOF
   GBFILE   = grib$fhr
   INDXFL   = 
   GDOUTF   = $GEMGRD
   PROJ     = $proj
   GRDAREA  = $grdarea
   KXKY     = $kxky
   MAXGRD   = $maxgrd
   CPYFIL   = $cpyfil
   GAREA    = $garea
   OUTPUT   = $output
   GBTBLS   = $gbtbls
   GBDIAG   = 
   PDSEXT   = $pdsext
  l
  r
EOF
  export err=$?;err_chk

  #####################################################
  # GEMPAK DOES NOT ALWAYS HAVE A NON ZERO RETURN CODE
  # WHEN IT CAN NOT PRODUCE THE DESIRED GRID.  CHECK
  # FOR THIS CASE HERE.
  #####################################################
  gpend

  #
  # Create ZAGL level products for the rap
  #
  if [ "$RUN" = "rap" -o "$RUN" = "rap20" -o "$RUN" = "rap32" ] ; then
    $GEMEXE/gdvint << EOF
     GDFILE   = $GEMGRD
     GDOUTF   = $GEMGRD
     GDATTIM  = f${fhr}
     GVCORD   = pres/zagl
     GLEVEL   = 500-9000-500
     MAXGRD   = 5000
     GAREA    = $garea
     VCOORD   = mslv;esfc
     l
     r
EOF
  fi


  #
  # Create theta level products for the RAP 
  #
  if [ "$RUN" = "rap" -o "$RUN" = "rap20" -o "$RUN" = "rap32" ] ; then
    $GEMEXE/gdvint << EOF
     GDFILE   = $GEMGRD
     GDOUTF   = $GEMGRD
     GDATTIM  = f${fhr}
     GVCORD   = pres/thta
     GLEVEL   = 270-330-3 
     MAXGRD   = 5000 
     GAREA    = 25;-120;50;-60 
     VCOORD   = /l 
     l
     r 
EOF
  fi

  if [ $SENDCOM = "YES" ] ; then
     cpfs $GEMGRD $COMAWP/$GEMGRD
     if [ $SENDDBN = "YES" ] ; then
       $DBNROOT/bin/dbn_alert MODEL ${DBN_ALERT_TYPE} $job \
           $COMAWP/$GEMGRD
     else
       echo "##### DBN_ALERT_TYPE is: ${DBN_ALERT_TYPE} #####"
     fi
  fi

  let fhcnt=fhcnt+finc
done

if [ $RUN = rap ]; then 
  ecflow_client --event release_meta
fi

#####################################################################
# GOOD RUN
set +x
echo "**************JOB $RUN NAWIPS COMPLETED NORMALLY ON THE IBM"
echo "**************JOB $RUN NAWIPS COMPLETED NORMALLY ON THE IBM"
echo "**************JOB $RUN NAWIPS COMPLETED NORMALLY ON THE IBM"
set -x
#####################################################################

#msg='Job completed normally.'
#echo $msg
postmsg "$jlogfile" "$msg"

############################### END OF SCRIPT #######################
