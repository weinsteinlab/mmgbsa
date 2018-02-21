#!/bin/bash -l
#SBATCH --job-name=mmgbsa2.1_final
#SBATCH -p cryo-cpu
#SBATCH --nodes=1
#SBATCH --mem=40G

source ~/.bashrc

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

tar czf ./sub_job_logs.tar.gz ./slurm-*.out
rm ./slurm-*.out

cd ..

cp -rp $cwd $TMPDIR/final_job_tmp

cd $TMPDIR/final_job_tmp
echo "Working in directory $TMPDIR/final_job_tmp/"

for file in `ls [0-9][0-9][0-9][0-9].tar.gz`; do
	tar -xzf $file
done
rm *.gz

$parallel_scripts/mmgbsa_collect_results_spack_R.sh ${traj} ${sub_job_num}  ${frames_per_job}

rm -r [0-9][0-9][0-9][0-9]

tar czf $cwd/final_results.tar.gz inter sas-a sas-b sas-comp solv-a solv-b solv-comp total *.dat

cp *.dat $cwd/.

rm -r inter sas-a sas-b sas-comp solv-a solv-b solv-comp total


exit
