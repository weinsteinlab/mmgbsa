#!/bin/bash -l
#$ -N mmgbsa2.2_final
#$ -j y
#$ -cwd
#$ -q standard.q
#$ -l h_vmem=10G

###################################################################
#                                                                 #
# User-defined parameters                                         #
#                                                                 #
###################################################################

traj=$1
sub_job_num=$2
frames_per_job=$3

source $mmgbsa_path/scripts/setenv.sh


###################################################################

cwd=$(pwd)

tar czf ./sub_job_logs.tar.gz ./mmgbsa2.2.o*
rm ./mmgbsa2.2.o*

cd ..

cp -rp $cwd $TMPDIR/final_job_tmp

cd $TMPDIR/final_job_tmp
echo "Working in directory $TMPDIR/final_job_tmp/"

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
