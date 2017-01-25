#!/bin/bash -l
#$ -N mmgbsa2.1_final
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

# mmgbsa_path=/home/mac2109/mmgbsa/mmgbsa2.1/
source $mmgbsa_path/scripts/setenv.sh

###################################################################

cwd=$(pwd)
# TMPDIR=$($parallel_scripts/grab_job_id_for_terminal.sh)
# TMPDIR="$cwd/../"


tar czf sub_job_logs.tar.gz mmgbsa2.o*
rm mmgbsa2.o*

cd ..

cp -rp $cwd $TMPDIR/final_job_tmp

cd $TMPDIR/final_job_tmp
echo "Working in directory $TMPDIR/final_job_tmp/"

#echo '#!/bin/bash' > un_tar.sh
#ls *.gz >> un_tar.sh
#sed -i '2,$ s/^/tar xzf /' un_tar.sh
#chmod 744 un_tar.sh
#./un_tar.sh
for file in `ls [0-9][0-9][0-9][0-9].tar.gz`; do
	tar -xzf $file
done
rm *.gz

$parallel_scripts/mmgbsa_collect_results.sh ${traj} ${sub_job_num}  ${frames_per_job}

# tar czf all_sub_jobs.tar.gz [0-9][0-9][0-9][0-9]

rm -r [0-9][0-9][0-9][0-9]

tar czf $cwd/final_results.tar.gz inter sas-a sas-b sas-comp solv-a solv-b solv-comp total *.dat

cp *.dat $cwd/.

rm -r inter sas-a sas-b sas-comp solv-a solv-b solv-comp total


exit
