#!/bin/bash -l

# SGE or LSF arguments given on command line

###################################################################
#                                                                 #
# User-defined parameters                                         #
#                                                                 #
###################################################################

traj=$1
sub_job_num=$2
frames_per_job=$3

source $mmgbsa_path/scripts/setenv.sh

#SGE :
if [ $queueing_system == "SGE" ]; then
        mytmpdir=$TMPDIR
fi
#LSF :
if [ $queueing_system == "LSF" ]; then
        mytmpdir=$__LSF_JOB_TMPDIR__
fi

echo "    Using temporary directory : $mytmpdir/final_job_tmp"

###################################################################

cwd=$(pwd)

tar czf ./sub_job_logs.tar.gz ./mmgbsa2.1.o*
rm ./mmgbsa2.1.o*

cd ..

cp -rp $cwd $mytmpdir/final_job_tmp

cd $mytmpdir/final_job_tmp
echo "Working in directory $mytmpdir/final_job_tmp/"

for file in `ls [0-9][0-9][0-9][0-9].tar.gz`; do
	tar -xzf $file
done
rm *.gz

$parallel_scripts/mmgbsa_collect_results_multitraj.sh ${traj} ${sub_job_num}  ${frames_per_job}

rm -r [0-9][0-9][0-9][0-9]

tar czf $cwd/final_results.tar.gz inter sas solv total log_collect *.dat

cp *.dat $cwd/.

rm -r inter sas solv total


exit
