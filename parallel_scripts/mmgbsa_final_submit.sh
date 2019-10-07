#!/bin/bash -l
#$ -N mmgbsa2.1_final
#$ -j y
#$ -cwd
#$ -q standard.q
#$ -l h_vmem=10G

# BSUB options submitted directly on the command line. 

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

#SGE :
if [ $queueing_system == "SGE" ]; then
        mytmpdir=$TMPDIR
        A=$SGE_TASK_ID
#LSF :
elif [ $queueing_system == "LSF" ]; then
        mytmpdir=$__LSF_JOB_TMPDIR__
        A=$LSB_JOBINDEX
#SLURM :
elif [ $queueing_system == "SLURM" ]; then
        mytmpdir=$TMPDIR
        A=$SLURM_ARRAY_TASK_ID
fi

tar czf ./sub_job_logs.tar.gz ./mmgbsa2.1.o* ./mmgbsa2.1.e*
rm ./mmgbsa2.1.o* ./mmgbsa2.1.e*

cd ..

cp -rp $cwd $mytmpdir/final_job_tmp

cd $mytmpdir/final_job_tmp
echo "Working in directory $mytmpdir/final_job_tmp/"

for file in `ls [0-9][0-9][0-9][0-9].tar.gz`; do
	tar -xzf $file
done
rm *.gz

$parallel_scripts/mmgbsa_collect_results.sh ${traj} ${sub_job_num}  ${frames_per_job}

rm -r [0-9][0-9][0-9][0-9]

tar czf $cwd/final_results.tar.gz inter sas-a sas-b sas-comp solv-a solv-b solv-comp total dg  *.dat

cp *.dat $cwd/.

rm -r inter sas-a sas-b sas-comp solv-a solv-b solv-comp total dg


exit
