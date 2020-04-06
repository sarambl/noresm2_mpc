
args=("$@")
CASENAME=${args[0]}  # uniquecasename, maybe add a timestamp in the python script

CASEROOT=/cluster/home/sarambl/cases_noresm2/${CASENAME}

cd $CASEROOT
sed -i 's/<arg flag="-p" name="$JOB_QUEUE"/<arg flag="--qos" name="$JOB_QUEUE"/' env_batch.xml

./xmlchange JOB_QUEUE='devel' --file env_batch.xml

./case.build
