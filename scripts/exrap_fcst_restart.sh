#!/bin/ksh -l
################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         exrap_fcst_restart.sh.ecf
# Script description:  runs the forecast job for the RAP
#
# Author:  Ming Hu / Geoff Manikin / Julia Zhu   Org: EMC     Date: 2011-08-24
#
# Script history log:
# 2011-08-24  M Hu / G Manikin / J Zhu
# 2018-02-05  B Blake - RAPv4

set -x
export WRFIO_NCD_LARGE_FILE_SUPPORT=1
export WRF_DFI_RADAR=1

# Set output directory
cd $DATA
# Copy boundary file into DATA
cp ${FCSTPROD}/wrfbdy_d01 ${DATA}

# Determine original START_TIME
firstfile=`ls ${FCSTPROD}/wrfout_d01* | head -n 1`
firstname=`basename ${firstfile}`
YYYY=`echo ${firstname} | cut -c 12-15`
MM=`echo ${firstname} | cut -c 17-18`
DD=`echo ${firstname} | cut -c 20-21`
HH=`echo ${firstname}  | cut -c 23-24` 

# Determine last forecast hour completed that is divisible by three and number of files to copy
lastfile=`ls ${FCSTPROD}/fcstdone[0-1][0-9]00.* | tail -n 1`
lastname=`basename ${lastfile}`
lasthour=`echo ${lastname} | cut -c 9-10`
lasthour=$(($lasthour - $lasthour%3))
filecount=$(($lasthour + 1))

# Copy fcstdone and wrfout files already completed
fcstdonelist=`ls ${FCSTPROD}/fcstdone* | head -n ${filecount}`
wrfoutlist=`ls ${FCSTPROD}/wrfout* | head -n ${filecount}`
lastwrfout=`ls ${wrfoutlist} | tail -n 1`
lastwrfoutname=`basename ${lastwrfout}`
cp -pr ${fcstdonelist} ${DATA}
cp ${FCSTPROD}/${lastwrfoutname} ${DATA}/.

# Set softlink to wrfinput
mv ${DATA}/${lastwrfoutname} ${DATA}/${lastwrfoutname}_output
ln -sf ${DATA}/${lastwrfoutname}_output ${DATA}/wrfinput_d01
# Set new START_TIME
DATE=/bin/date
ORIG_START_TIME="${YYYY}${MM}${DD} ${HH}"
ORIG_START_TIME_STRING="${YYYY}-${MM}-${DD}_${HH}:00:00"
START_TIME=`${DATE} +"%Y%m%d%H" -d "${ORIG_START_TIME} ${lasthour} hours"`
START_TIME_STRING=`${DATE} +"%Y%m%d %H" -d "${ORIG_START_TIME} ${lasthour} hours"`
NEWHH=`${DATE} +"%H" -d "${START_TIME_STRING}"`

# Set up the work directory and cd into it
cd ${DATA}

export WPSNAMELIST=namelist.wps
echo $START_TIME >STARTTIME

# Adjust FCST_LENGTH
if [ $cyc -eq 03 -o $cyc -eq 09 -o $cyc -eq 15 -o $cyc -eq 21 ] ; then
  export FCST_LENGTH=$((39 - $lasthour))
else
  export FCST_LENGTH=$((21 - $lasthour))
fi

# Set up some constants
export FCST_INTERVAL="1"
export RUNLENGTH_DFI_FWD="10"
export RUNLENGTH_DFI_BCK="20"
export METGRIDPROC="METGRID_PROC"
export BOUNDARY=${BOUNDARY:-$RAPBC}

# Compute date & time components for the forecast
ymd=`echo ${START_TIME} | cut -c1-8`
ymdh=`echo ${START_TIME} | cut -c1-10`
mdh=`echo ${START_TIME} | cut -c5-10`
hh=`echo ${START_TIME} | cut -c9-10`
END_TIME=`$NDATE +${FCST_LENGTH} $START_TIME`
syyyy=`echo ${START_TIME} | cut -c1-4`
smm=`echo ${START_TIME} | cut -c5-6`
sdd=`echo ${START_TIME} | cut -c7-8`
shh=`echo ${START_TIME} | cut -c9-10`
eyyyy=`echo ${END_TIME} | cut -c1-4`
emm=`echo ${END_TIME} | cut -c5-6`
edd=`echo ${END_TIME} | cut -c7-8`
ehh=`echo ${END_TIME} | cut -c9-10`
start_yyyymmdd_hhmmss=${syyyy}-${smm}-${sdd}_${shh}:00:00
end_yyyymmdd_hhmmss=${eyyyy}-${emm}-${edd}_${ehh}:00:00
cyc=`echo ${START_TIME} | cut -c9-10`
ymd=`echo ${START_TIME} | cut -c1-8`

# Calculate the DFI forward end time
DFIFWD_END_TIME=`$NDATE +0 $START_TIME`

# Calculate the DFI backward end time
DFIBCK_END_TIME=`$NDATE -1 $START_TIME`

# Recommended MPI environment variable setttings from IBM
# (Appendix E, HPC Clusters Using InfiniBand on IBM Power Systems Servers)
export OMP_NUM_THREADS=2

# Print run parameters
echo
echo "wrf.ksh started at `${DATE}`"
echo
echo "FCST LENGTH   = ${FCST_LENGTH}"
echo "FCST INTERVAL = ${FCST_INTERVAL}"
echo
echo "START TIME = "${START_TIME}"
echo " END TIME = "${END_TIME}"
echo "DFIFWD_END_TIME= "${DFIFWD_END_TIME}"
echo "DFIBCK_END_TIME= "${DFIBCK_END_TIME}"
echo

# Set the pathname of the WRF namelist
WRF_NAMELIST=namelist.input

# Copy the wrf namelist to the static dir
cp ${PARMrap}/rap_wrf_restart.nl ${WRF_NAMELIST}

# Initialize an array of WRF input dat files that need to be linked
set -A WRF_DAT_FILES ${PARMrap}/rap_run_LANDUSE.TBL          \
                     ${PARMrap}/rap_run_RRTM_DATA            \
                     ${PARMrap}/rap_run_RRTM_DATA_DBL        \
                     ${PARMrap}/rap_run_RRTMG_LW_DATA        \
                     ${PARMrap}/rap_run_RRTMG_LW_DATA_DBL    \
                     ${PARMrap}/rap_run_RRTMG_SW_DATA        \
                     ${PARMrap}/rap_run_RRTMG_SW_DATA_DBL    \
                     ${PARMrap}/rap_run_VEGPARM.TBL          \
                     ${PARMrap}/rap_run_GENPARM.TBL          \
                     ${PARMrap}/rap_run_SOILPARM.TBL         \
                     ${PARMrap}/rap_run_MPTABLE.TBL          \
                     ${PARMrap}/rap_run_URBPARM.TBL          \
                     ${PARMrap}/rap_run_URBPARM_UZE.TBL      \
                     ${PARMrap}/rap_run_ETAMPNEW_DATA        \
                     ${PARMrap}/rap_run_ETAMPNEW_DATA.expanded_rain        \
                     ${PARMrap}/rap_run_ETAMPNEW_DATA.expanded_rain_DBL    \
                     ${PARMrap}/rap_run_ETAMPNEW_DATA_DBL    \
                     ${PARMrap}/rap_run_co2_trans            \
                     ${PARMrap}/rap_run_ozone.formatted      \
                     ${PARMrap}/rap_run_ozone_lat.formatted  \
                     ${PARMrap}/rap_run_ozone_plev.formatted \
                     ${PARMrap}/rap_run_tr49t85              \
                     ${PARMrap}/rap_run_tr49t67              \
                     ${PARMrap}/rap_run_tr67t85              \
                     ${PARMrap}/rap_run_grib2map.tbl         \
                     ${PARMrap}/rap_run_gribmap.txt          \
                     ${PARMrap}/rap_run_aerosol.formatted      \
                     ${PARMrap}/rap_run_aerosol_lat.formatted  \
                     ${PARMrap}/rap_run_aerosol_lon.formatted  \
                     ${PARMrap}/rap_run_aerosol_plev.formatted \
                     ${PARMrap}/rap_run_bulkdens.asc_s_0_03_0_9  \
                     ${PARMrap}/rap_run_bulkradii.asc_s_0_03_0_9 \
                     ${PARMrap}/rap_run_capacity.asc           \
                     ${PARMrap}/rap_run_CCN_ACTIVATE.BIN       \
                     ${PARMrap}/rap_run_coeff_p.asc            \
                     ${PARMrap}/rap_run_coeff_q.asc            \
                     ${PARMrap}/rap_run_constants.asc          \
                     ${PARMrap}/rap_run_kernels.asc_s_0_03_0_9 \
                     ${PARMrap}/rap_run_kernels_z.asc          \
                     ${PARMrap}/rap_run_masses.asc             \
                     ${PARMrap}/rap_run_termvels.asc           \
                     ${PARMrap}/rap_run_wind-turbine-1.tbl     \
                     ${PARMrap}/rap_run_freezeH2O.dat          \
                     ${PARMrap}/rap_run_qr_acr_qg.dat          \
                     ${PARMrap}/rap_run_qr_acr_qs.dat

# Make links to the WRF DAT files
for file in ${WRF_DAT_FILES[@]}; do
  tempfile=`basename ${file}`
  tempname=`echo ${tempfile} | sed s/rap_run_//`
  rm -f ${tempname}
  ln -s ${file} ${tempname}
done

# Get the start and end time components
start_year=`echo ${START_TIME} | cut -c1-4`
start_month=`echo ${START_TIME} | cut -c5-6`
start_day=`echo ${START_TIME} | cut -c7-8`
start_hour=`echo ${START_TIME} | cut -c9-10`
start_minute="00"
start_second="00"
end_year=`echo ${END_TIME} | cut -c1-4`
end_month=`echo ${END_TIME} | cut -c5-6`
end_day=`echo ${END_TIME} | cut -c7-8`
end_hour=`echo ${END_TIME} | cut -c9-10`
end_minute="00"
end_second="00"
start_YYYYMMDDHHMM=${start_year}${start_month}${start_day}${start_hour}${start_minute}

# for DFI
dfi_fwdstop_year=`echo ${DFIFWD_END_TIME} | cut -c1-4`
dfi_fwdstop_month=`echo ${DFIFWD_END_TIME} | cut -c5-6`
dfi_fwdstop_day=`echo ${DFIFWD_END_TIME} | cut -c7-8`
dfi_fwdstop_hour=`echo ${DFIFWD_END_TIME} | cut -c9-10`
dfi_fwdstop_minute=`echo ${RUNLENGTH_DFI_FWD}`
dfi_fwdstop_second="00"
dfi_bckstop_year=`echo ${DFIBCK_END_TIME} | cut -c1-4`
dfi_bckstop_month=`echo ${DFIBCK_END_TIME} | cut -c5-6`
dfi_bckstop_day=`echo ${DFIBCK_END_TIME} | cut -c7-8`
dfi_bckstop_hour=`echo ${DFIBCK_END_TIME} | cut -c9-10`
(( BCK_MIN = 60 - ${RUNLENGTH_DFI_BCK} ))
dfi_bckstop_minute=`echo ${BCK_MIN}`
dfi_bckstop_second="00"


# Compute number of days and hours for the run
#(( run_days = ${FCST_LENGTH} / 24 ))
#(( run_hours = ${FCST_LENGTH} % 24 ))
(( run_days = 0 ))
(( run_hours = 0 ))

# Create patterns for updating the wrf namelist
run=[Rr][Uu][Nn]
equal=[[:blank:]]*=[[:blank:]]*
start=[Ss][Tt][Aa][Rr][Tt]
end=[Ee][Nn][Dd]
year=[Yy][Ee][Aa][Rr]
month=[Mm][Oo][Nn][Tt][Hh]
day=[Dd][Aa][Yy]
hour=[Hh][Oo][Uu][Rr]
minute=[Mm][Ii][Nn][Uu][Tt][Ee]
second=[Ss][Ee][Cc][Oo][Nn][Dd]
interval=[Ii][Nn][Tt][Ee][Rr][Vv][Aa][Ll]
#for DFI
dfi=[Dd][Ff][Ii]
fwdstop=[Ff][Ww][Dd][Ss][Tt][Oo][Pp]
bckstop=[Bb][Cc][Kk][Ss][Tt][Oo][Pp]
runlength=[Rr][Uu][Nn][Ll][Ee][Nn][Gg][Tt][Hh]
fwd=[Ff][Ww][Dd]
bck=[Bb][Cc][Kk]

# Update the run_days in wrf namelist.input
cat ${WRF_NAMELIST} | sed "s/\(${run}_${day}[Ss]\)${equal}[[:digit:]]\{1,\}/\1 = ${run_days}/" \
   > ${WRF_NAMELIST}.new
mv ${WRF_NAMELIST}.new ${WRF_NAMELIST}

# Update the run_hours in wrf namelist
cat ${WRF_NAMELIST} | sed "s/\(${run}_${hour}[Ss]\)${equal}[[:digit:]]\{1,\}/\1 = ${run_hours}/" \
   > ${WRF_NAMELIST}.new
mv ${WRF_NAMELIST}.new ${WRF_NAMELIST}

cat ${WRF_NAMELIST} | sed "s/\(${start}_${year}\)${equal}[[:digit:]]\{4\}/\1 = ${start_year}/" \
   | sed "s/\(${start}_${month}\)${equal}[[:digit:]]\{2\}/\1 = ${start_month}/"                   \
   | sed "s/\(${start}_${day}\)${equal}[[:digit:]]\{2\}/\1 = ${start_day}/"                       \
   | sed "s/\(${start}_${hour}\)${equal}[[:digit:]]\{2\}/\1 = ${start_hour}/"                     \
   | sed "s/\(${start}_${minute}\)${equal}[[:digit:]]\{2\}/\1 = ${start_minute}/"                 \
   | sed "s/\(${start}_${second}\)${equal}[[:digit:]]\{2\}/\1 = ${start_second}/"                 \
   > ${WRF_NAMELIST}.new
mv ${WRF_NAMELIST}.new ${WRF_NAMELIST}

# Update end time in namelist
cat ${WRF_NAMELIST} | sed "s/\(${end}_${year}\)${equal}[[:digit:]]\{4\}/\1 = ${end_year}/" \
   | sed "s/\(${end}_${month}\)${equal}[[:digit:]]\{2\}/\1 = ${end_month}/"                   \
   | sed "s/\(${end}_${day}\)${equal}[[:digit:]]\{2\}/\1 = ${end_day}/"                       \
   | sed "s/\(${end}_${hour}\)${equal}[[:digit:]]\{2\}/\1 = ${end_hour}/"                     \
   | sed "s/\(${end}_${minute}\)${equal}[[:digit:]]\{2\}/\1 = ${end_minute}/"                 \
   | sed "s/\(${end}_${second}\)${equal}[[:digit:]]\{2\}/\1 = ${end_second}/"                 \
   > ${WRF_NAMELIST}.new
mv ${WRF_NAMELIST}.new ${WRF_NAMELIST}

# Update DFI forward end time in namelist
cat ${WRF_NAMELIST} | sed "s/\(${dfi}_${fwdstop}_${year}\)${equal}[[:digit:]]\{4\}/\1 = ${dfi_fwdstop_year}/" \
   | sed "s/\(${dfi}_${fwdstop}_${month}\)${equal}[[:digit:]]\{2\}/\1 = ${dfi_fwdstop_month}/"     \
   | sed "s/\(${dfi}_${fwdstop}_${day}\)${equal}[[:digit:]]\{2\}/\1 = ${dfi_fwdstop_day}/"         \
   | sed "s/\(${dfi}_${fwdstop}_${hour}\)${equal}[[:digit:]]\{2\}/\1 = ${dfi_fwdstop_hour}/"       \
   | sed "s/\(${dfi}_${fwdstop}_${minute}\)${equal}[[:digit:]]\{2\}/\1 = ${dfi_fwdstop_minute}/"   \
   | sed "s/\(${dfi}_${fwdstop}_${second}\)${equal}[[:digit:]]\{2\}/\1 = ${dfi_fwdstop_second}/"   \
   > ${WRF_NAMELIST}.new
mv ${WRF_NAMELIST}.new ${WRF_NAMELIST}

# Update DFI backward end time in namelist
cat ${WRF_NAMELIST} | sed "s/\(${dfi}_${bckstop}_${year}\)${equal}[[:digit:]]\{4\}/\1 = ${dfi_bckstop_year}/" \
   | sed "s/\(${dfi}_${bckstop}_${month}\)${equal}[[:digit:]]\{2\}/\1 = ${dfi_bckstop_month}/"     \
   | sed "s/\(${dfi}_${bckstop}_${day}\)${equal}[[:digit:]]\{2\}/\1 = ${dfi_bckstop_day}/"         \
   | sed "s/\(${dfi}_${bckstop}_${hour}\)${equal}[[:digit:]]\{2\}/\1 = ${dfi_bckstop_hour}/"       \
   | sed "s/\(${dfi}_${bckstop}_${minute}\)${equal}[[:digit:]]\{2\}/\1 = ${dfi_bckstop_minute}/"   \
   | sed "s/\(${dfi}_${bckstop}_${second}\)${equal}[[:digit:]]\{2\}/\1 = ${dfi_bckstop_second}/"   \
   > ${WRF_NAMELIST}.new
mv ${WRF_NAMELIST}.new ${WRF_NAMELIST}

# Update runlenfth_dfi_fwd  in namelist
cat ${WRF_NAMELIST} | sed "s/\(${runlength}_${dfi}_${fwd}\)${equal}[[:digit:]]\{1,\}/\1 = ${RUNLENGTHDFI_FWD}/" \
   > ${WRF_NAMELIST}.new
mv ${WRF_NAMELIST}.new ${WRF_NAMELIST}

# Update runlenfth_dfi_bck  in namelist
cat ${WRF_NAMELIST} | sed "s/\(${runlength}_${dfi}_${bck}\)${equal}[[:digit:]]\{1,\}/\1 = ${RUNLENGTH_DFI_BCK}/" \
   > ${WRF_NAMELIST}.new
mv ${WRF_NAMELIST}.new ${WRF_NAMELIST}

# MPI settings for forecast
#grid_order -C -c 2,6 -g 10,60 > MPICH_RANK_ORDER
#export MPICH_RANK_REORDER_METHOD=3
#export MALLOC_MMAP_MAX=0
#export MALLOC_TRIM_THRESHOLD=134217728
#export MPICH_MPIIO_HINTS="wrfinput*:cb_nodes=24,wrfrst*:cb_nodes=24,wrfout*:cb_nodes=24"
#export MPICH_MPIIO_AGGREGATOR_PLACEMENT_DISPLAY=1
#export MPICH_ENV_DISPLAY=1
#export MPICH_VERSION_DISPLAY=1
#export MPICH_ABORT_ON_ERROR=1
#export MPICH_MPIIO_STATS=1
#export ATP_ENABLED=0

############################################################
# Run WRF.

cp ${EXECrap}/rap_wrfarw_fcst .

module unload craype-hugepages2M
module unload craype-hugepages4M
module unload craype-hugepages16M
module unload craype-hugepages32M
module unload craype-hugepages64M
module unload craype-hugepages128M
module unload craype-hugepages256M
module unload craype-hugepages512M

set -e
module load craype-hugepages8M
set +e

# 72 node configuration for RAP forecast
cat<<EOF > run_wrf_config
omp_num_threads=2 # compute only; quilt is always 1
hyperthreads=1    # compute only
io_hyperthreads=1 # quilt only
turbo_mode=YES    # compute only; YES or NO
reorder_ranks=grid_order # grid_order or NO
mpich_tuning=cb_nodes # cb_nodes or NO

# Distribution of compute nodes in grid:
nnode_x=8
nnode_y=8

# Distribution of MPI ranks within each compute node:
nrank_x=2
nrank_y=6

# Quilt server configuration:
nio_tasks_per_group=48
nio_groups=3
nio_ppn=24
cb_nodes=24
EOF

if ( ! $USHrap/rap_run_wrf.sh rap_wrfarw_fcst run_wrf_config ) ; then
    err_exit "WRF-ARW execution wrapper script failed."
fi
############################################################

# Change wrfout metadata to original START_TIME
for wrfout in `ls wrfout_d01_*`
do
  ncatted -O -h -a START_DATE,global,o,c,"${ORIG_START_TIME_STRING}" ${wrfout}
  ncatted -O -h -a SIMULATION_START_DATE,global,o,c,"${ORIG_START_TIME_STRING}" ${wrfout}
  mv ${wrfout} ${FCSTPROD}/.
done

# Rename fcstdone files to format from original START_TIME
for fcstdone in `ls fcstdone*.${NEWHH}`
do
   NEWFF=`echo ${fcstdone} | cut -c 9-10`
   NEWMM=`echo ${fcstdone} | cut -c 11-12`
   typeset -Z2 FF=$(($NEWFF + $lasthour))
   mv ${fcstdone} ${FCSTPROD}/fcstdone${FF}${NEWMM}.${HH}
done

cp rsl.out.0000 ${COMOUT}/rap.t${cyc}z.rslout

msg="JOB $job FOR RAP_FORECAST_RESTART HAS COMPLETED NORMALLY"
postmsg "$jlogfile" "$msg"

exit 0

