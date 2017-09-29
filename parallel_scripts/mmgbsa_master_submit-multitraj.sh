#!/bin/bash -l
#$ -N mmgbsa2.1
#$ -j y
#$ -cwd
#$ -q standard.q
#$ -l h_vmem=5G
##$ -l h_vmem=5G,zeno=true

###################################################################
#                                                                 #
# User-defined parameters, now passed as arguments                #
#                                                                 #
###################################################################

# TEST! Just to see how GitLab documents command line-pushed changes. 

# Trajectory of the full system (can be a DCD file or an XTC file)
mytraj=$1
# Start frame of the main trajectory
real_first=$2
# Frame stride in the main trajectory
stride=$3
# Number of frames per job
js=$4 # number of frames in each sub-job


###################################################################
# Setup some variables 

psf=./data/system.namd.psf

A=$SGE_TASK_ID
B=`printf %04i $A`

# mmgbsa_path=/home/mac2109/mmgbsa/mmgbsa2.1/
# This is now inherited by the environment through qsub -V
source $mmgbsa_path/scripts/setenv.sh
catdcd=$mmgbsa_path/parallel_scripts/catdcd 

current=$(pwd)

mj=$(( $js - 1 ))

dcd_tmp=$TMPDIR/job_${B}
main_tmp=$TMPDIR/${B}

if [[ ${mytraj##*.} == "xtc" ]] ; then
	trajtypeflag="-xtc"
elif [[ ${mytraj##*.} == "dcd" ]] ; then
	trajtypeflag="-dcd"
else
	echo "ERROR : Unrecognized trajectory file type"
	exit 1
fi

###################################################################
# Make directories and small trajectory

time_to_sleep=$(( $SGE_TASK_ID % 3 ))
sleep $time_to_sleep  

mkdir $dcd_tmp
mkdir $main_tmp

cp -rp data $main_tmp/.
cp -rp vmd_selections.tcl $main_tmp/.

# Update the loader file for the local directory
#sed -i "s|BASEDIR|$main_tmp\/data|" $inputs/loader.str  $main_tmp/data/loader.str

cd $current

# Get the total number of frames in the trajectory
frame_num=` $catdcd -num $trajtypeflag $mytraj | awk '($1=="Total"){print $3}'  `

if (( $frame_num  == 0 ))
then
	echo "ERROR : No frames could be read from trajectory!"
	pwd
	exit 1
fi


echo " Extracting small trajectory ... "
if (( $frame_num % $js == 0 ))
then
	final_job=$((frame_num/$js))

	if [ $A -le 1 ]
	then	
		$catdcd -o $dcd_tmp/$B.dcd -otype dcd -first 1 -last $js $trajtypeflag $mytraj
	else
		last=$(($A*$js))
        	first=$((last-$mj))
		$catdcd -o $dcd_tmp/$B.dcd -otype dcd -first $first -last $last $trajtypeflag $mytraj
	fi
else
	final_job=$(((frame_num/$js)+1))

        if [ $A -le 1 ]
        then
                $catdcd -o $dcd_tmp/$B.dcd -otype dcd -first 1 -last $js $trajtypeflag $mytraj
        elif [ $A -lt $final_job ] 
	then
                last=$(($A*$js))
                first=$((last-$mj))
                $catdcd -o $dcd_tmp/$B.dcd -otype dcd -first $first -last $last $trajtypeflag $mytraj
	else 
                first=$((($A*$js)-$mj))
		$catdcd -o $dcd_tmp/$B.dcd -otype dcd -first $first -last $frame_num $trajtypeflag $mytraj
        fi	
fi

unset frame_num

small_traj=$dcd_tmp/$B.dcd

# Get the number of frames in the local trajectory bit
last=`$catdcd -num $small_traj | awk '($1=="Total"){print $3}'`


###################################################################
# Prepare local mmgbsa 

cd $main_tmp

$catdcd -o ./data/first_frame_of_dcd.pdb -otype pdb -s $psf -stype psf -first $real_first -last 1 $small_traj

echo " "
echo "Task ID : $SGE_TASK_ID"
echo "Host : " `hostname`
echo "Base directory : $current"
echo "Working directory : $main_tmp"
echo "DCD directory : $dcd_tmp"

echo " "
echo " Preparing local MMGBSA job ... "
$mmgbsa_path/scripts/prepare_mmgbsa_local.csh $small_traj 1 $last $stride $dcd_tmp > $current/log/prepare_job_$SGE_TASK_ID.log

###################################################################
# Run local mmgbsa 

echo " Running local MMGBSA job ... "
$mmgbsa_path/scripts/run_one_mmgbsa-multitraj.sh  >  $current/log/run_job_$SGE_TASK_ID.log


sleep 10

echo " Cleaning up ... "
#rm -r ./frames-a 
#rm -r ./frames-b 
#rm -r ./frames-comp 
#rm -r ./data

#rm -r $dcd_tmp

cd $TMPDIR

tar czf $B.tar.gz $B 
rm -r $B
mv $B.tar.gz $current/.

echo "Done."
exit
