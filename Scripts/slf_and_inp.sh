#!/bin/bash
# ^specify bash as interpreter

# Copied from slf_only.sh by Jonah Shaw 19/11/05
# Useful documentation on where to make model adjustments:
#   http://www.cesm.ucar.edu/events/tutorials/2018/files/Practical4-intro-hannay.pdf

############
# FUNCTIONS
############

# Search and replace function
function ponyfyer() {
    local search=$1 ;
    local replace=$2 ;
    local loc=$3 ;
    # Note the double quotes
    sed -i "s/${search}/${replace}/g" ${loc} ;
}

################
# SET INPUT ARGS
################

args=("$@")
CASENAME=${args[0]}  # uniquecasename, maybe add a timestamp in the python script
wbf=${args[1]}          # wbf multiplier
inp=${args[2]}          # inp multiplier

#echo ${args[0]} ${args[1]} ${args[2]}

#####################
# SET CASE PARAMETERS
#####################

models=("noresm-dev" "cesm" "noresm-dev-10072019")
compsets=("NF2000climo" "N1850OCBDRDDMS" "NFAMIPNUDGEPTAEROCLB")
resolutions=("f19_tn14" "f10_f10_mg37", 'f19_g16')
machines=('fram')
projects=('nn9600k' 'nn9252k')
start=('2000-01-01' '2009-06-01') # start date
nudge=('ERA_f19_g16' 'ERA_f19_tn14') # repository where data for nudging is stored
########################
# OPTIONAL MODIFICATIONS
########################

nudge_winds=true
remove_entrained_ice=false
record_mar_input=false
run_type=paramtest # fouryear, devel, paramtest
run_period=sat_comp # standard, sat_comp
## Build the case

# Where ./create_case is called from: (do I need a tilde here for simplicity?)
ModelRoot=/cluster/home/jonahks/p/jonahks/models/${models[0]}/cime/scripts

# Where the case it setup, and user_nl files are stored
CASEROOT=/cluster/home/jonahks/p/jonahks/cases

# Where FORTRAN files contains microphysics modifications are stored
#ModSource=/cluster/home/jonahks/git_repos/noresm2_mpc/SourceMods
ModSource=/cluster/home/jonahks/git_repos/mpcSourceMods

# Set indices to select from arrays here
COMPSET=${compsets[0]}
RES=${resolutions[0]}
MACH=${machines[0]}
PROJECT=${projects[1]}
MISC=--run-unsupported

if [ $run_period = sat_comp ] ; then
    startdate=${start[1]}
    nudgedir=${nudge[1]}
else
    startdate=${start[0]}
    nudgedir=${nudge[0]}
fi
NUMNODES=-16 # How many nodes each component should run on

echo ${CASEROOT}/${CASENAME} ${COMPSET} ${RES} ${MACH} ${PROJECT} $MISC

#############
# Main Script
#############

cd ${ModelRoot} # Move to appropriate directory
#pwd

# Create env_*.xml files
./create_newcase --case ${CASEROOT}/${CASENAME} \
                 --compset ${COMPSET} \
                 --res ${RES} \
                 --mach ${MACH} \
                 --project ${PROJECT} \
                 $MISC

cd ${CASEROOT}/${CASENAME} # Move to the case's dir

# Set run time and restart variables within env_run.xml
if [ $run_type = devel ] ; then
    # ./xmlchange STOP_OPTION='nmonth',STOP_N='1' --file env_run.xml # standard is 5 days
    ./xmlchange JOB_WALLCLOCK_TIME=00:29:59 --file env_batch.xml
    ./xmlchange NTASKS=-4,NTASKS_ESP=1 --file env_mach_pes.xml
    ./xmlchange JOB_QUEUE='devel' --file env_batch.xml
elif [ $run_type = fouryear ] ; then 
    ./xmlchange STOP_OPTION='nmonth',STOP_N='48' --file env_run.xml
    ./xmlchange JOB_WALLCLOCK_TIME=11:59:59 --file env_batch.xml --subgroup case.run
    ./xmlchange NTASKS=-16,NTASKS_ESP=1 --file env_mach_pes.xml # arbitrary
    ./xmlchange --append CAM_CONFIG_OPTS='-cosp' --file env_build.xml
elif [ $run_type = paramtest ] ; then
    ./xmlchange STOP_OPTION='nmonth',STOP_N='15' --file env_run.xml
    ./xmlchange JOB_WALLCLOCK_TIME=11:59:59 --file env_batch.xml --subgroup case.run
    ./xmlchange NTASKS=-16,NTASKS_ESP=1 --file env_mach_pes.xml # arbitrary
else
    ./xmlchange STOP_OPTION='nmonth',STOP_N='15' --file env_run.xml
    ./xmlchange JOB_WALLCLOCK_TIME=11:59:59 --file env_batch.xml --subgroup case.run
    ./xmlchange NTASKS=-16,NTASKS_ESP=1 --file env_mach_pes.xml # arbitrary
fi

./xmlchange RUN_STARTDATE=$startdate --file env_run.xml
# ./xmlchange --append CAM_CONFIG_OPTS='-cosp' --file env_build.xml

#./xmlchange --file=env_run.xml RESUBMIT=3
# ./xmlchange --file=env_run.xml REST_OPTION=nyears
#./xmlchange --file=env_run.xml REST_N=5


# OPTIONAL: Remove entrainment of ice above -35C.
if [ $remove_entrained_ice = true ] ; then
    echo "Adding SourceMod to remove ice entrainment"
    cp ${ModSource}/clubb_intr.F90 /${CASEROOT}/${CASENAME}/SourceMods/src.cam
fi

# OPTIONAL: Nudge winds (pt. 1)
if [ $nudge_winds = true ] ; then
    echo "Making modifications to nudge uv winds. Make sure pt. 2 files are correct."
    ./xmlchange --append CAM_CONFIG_OPTS='--offline_dyn' --file env_build.xml
    ./xmlchange CALENDAR='GREGORIAN' --file env_build.xml 
    # ./xmlchange RUN_STARTDATE=$startdate --file env_run.xml
    # Not sure if this is necessary
    cp /cluster/home/jonahks/p/jonahks/models/noresm-dev/components/cam/src/NorESM/fv/metdata.F90 /${CASEROOT}/${CASENAME}/SourceMods/src.cam
fi

# ./case.setup
# Sets up case, creating user_nl_* files. 
# namelists can be modified here, or after ./case.build
# SourceMods are made here.

# Move modified WBF process into SourceMods dir:
cp ${ModSource}/micro_mg_cam.F90 /${CASEROOT}/${CASENAME}/SourceMods/src.cam
cp ${ModSource}/micro_mg2_0.F90 /${CASEROOT}/${CASENAME}/SourceMods/src.cam

# Move modified INP nucleation process into SourceMods dir:
cp ${ModSource}/hetfrz_classnuc_oslo.F90 /${CASEROOT}/${CASENAME}/SourceMods/src.cam

# Now use ponyfyer to set the values within the sourcemod files. Ex:
mg2_path=/${CASEROOT}/${CASENAME}/SourceMods/src.cam/micro_mg2_0.F90
inp_path=/${CASEROOT}/${CASENAME}/SourceMods/src.cam/hetfrz_classnuc_oslo.F90

ponyfyer 'wbf_tag = 1.' "wbf_tag = ${wbf}" ${mg2_path}  # wbf modifier
ponyfyer 'inp_tag = 1.' "inp_tag = ${inp}" ${inp_path} # aerosol conc. modifier

# exit 1

# Set up case, creating user_nl_* files
./case.setup

# Will need to modify the nl files appropriately here to choose output
# CAM adjustments, I don't entirely understand the syntax here, but all the formatting after the first line is totally preserved:
# list variables to add to first history file here
#&aerosol_nl  # Not sure what this is.
# , 'SLFXCLD_ISOTM', 'SADLIQXCLD_ISOTM', 'SADICEXCLD_ISOTM', 'BERGOXCLD_ISOTM',
# 'BERGSOXCLD_ISOTM', 'CLD_ISOTM', 'CLDTAU', 'CLD_SLF', 'CLD_ISOTM_SLF',

cat <<TXT2 >> user_nl_cam
fincl1 = 'BERGO', 'BERGSO', 'MNUCCTO', 'MNUCCRO', 'MNUCCCO', 'MNUCCDOhet', 'MNUCCDO'
         'DSTFREZIMM', 'DSTFREZCNT', 'DSTFREZDEP', 'BCFREZIMM', 'BCFREZCNT', 'BCFREZDEP',
         'NUMICE10s', 'NUMICE10sDST', 'NUMICE10sBC',
         'dc_num', 'dst1_num', 'dst3_num', 'bc_c1_num', 'dst_c1_num', 'dst_c3_num',
         'bc_num_scaled', 'dst1_num_scaled', 'dst3_num_scaled' ,
         'DSTNIDEP', 'DSTNICNT', 'DSTNIIMM',
         'BCNIDEP', 'BCNICNT', 'BCNIIMM', 'NUMICE10s', 'NUMIMM10sDST', 'NUMIMM10sBC',
         'MPDI2V', 'MPDI2W','QISEDTEN', 'NIMIX_HET', 'NIMIX_CNT', 'NIMIX_IMM', 'NIMIX_DEP',
         'MNUDEPO', 'NNUCCTO', 'NNUCCCO', 'NNUDEPO', 'NIHOMOO','HOMOO'
TXT2

# OPTIONAL: Nudge winds (pt. 2)
# user_nl_cam additions related to nudging. Specify winds, set relax time, set first wind field file, path to all windfield files
# The f16_g16 resolution only has ERA data from 1999-01-01 to 2003-07-14
# Setting drydep_method resolves an error that arises when using the NF2000climo compset
if [ $nudge_winds = true ] ; then # 

# Strings as formatted to give correct startdate and resolution directories (assuming they exist)
cat <<TXT3 >> user_nl_cam
&metdata_nl
 met_nudge_only_uvps = .true.
 met_data_file= "/cluster/shared/noresm/inputdata/noresm-only/inputForNudging/$nudgedir/$startdate.nc"
 met_filenames_list = "/cluster/shared/noresm/inputdata/noresm-only/inputForNudging/$nudgedir/fileList3.txt"
 met_rlx_top = 6
 met_rlx_bot = 6
 met_rlx_bot_top = 6
 met_rlx_bot_bot = 6  
 met_rlx_time = 6
 drydep_method = 'xactive_atm'
&cam_initfiles_nl
 bnd_topo = "/cluster/shared/noresm/inputdata/noresm-only/inputForNudging/$nudgedir/ERA_bnd_topo.nc"
TXT3

fi

if [ $record_mar_input = true ] ; then # Output additional history files with forcing input for MAR (Stefan)

# Does Stefan want instantaneous or average values?? instantaneous is better
cat <<MAR_CAM >> user_nl_cam
fincl2 = 'T:I','PS:I','Q:I','U:I','V:I'
nhtfr(2) = -6

fincl3 = 'SST:I'
nhtfr(3) = -24
MAR_CAM

cat <<MAR_CICE >> user_nl_cice
fincl3 = 'f_aice:I'
nhtfr(3) = -24
MAR_CICE

fi
# missing sea ice concentration (likely related to a different module)

exit 1

# build, create *_in files under run/
./case.build

exit 1

# Submit the case
./case.submit
