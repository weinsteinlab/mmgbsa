#!/bin/bash -l  

# BSUB options passed directly on the command line.

#$ -N mmgbsa2.1
#$ -j y
#$ -cwd
#$ -q standard.q
#$ -l h_vmem=10G

###################################################################
#                                                                 #
# User-defined parameters, now passed as arguments                #
#                                                                 #
###################################################################

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

psf=./data/system.namd.pdb

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
B=`printf %04i $A`

# mmgbsa_path=/home/mac2109/mmgbsa/mmgbsa2.1/
# This is now inherited by the environment through the queueing system command line
echo "mmgbsa_path : $mmgbsa_path"
export mmgbsa_path
source $mmgbsa_path/scripts/setenv.sh
catdcd=$mmgbsa_path/parallel_scripts/catdcd 

current=$(pwd)

mj=$(( $js - 1 ))

frames_tmp=$mytmpdir/frames_${B}
main_tmp=$mytmpdir/${B}

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

time_to_sleep=$(( $A % 3 ))
sleep $time_to_sleep  

mkdir $frames_tmp
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


# echo " Extracting small trajectory ... "
if (( $frame_num % $js == 0 ))
then
	final_job=$((frame_num/$js))

	if [ $A -le 1 ]
	then	
		first=1
		last=$js
	else
		last=$(($A*$js))
        	first=$((last-$mj))
	fi
else
	final_job=$(((frame_num/$js)+1))

        if [ $A -le 1 ]
        then
                first=1
                last=$js
        elif [ $A -lt $final_job ] 
	then
                last=$(($A*$js))
                first=$((last-$mj))
	else 
                first=$((($A*$js)-$mj))
		last=$frame_num
        fi	
fi

unset frame_num

# small_traj=$frames_tmp/$B.dcd
# $catdcd -o $small_traj -otype dcd -first $first -last $last $trajtypeflag $mytraj


# Get the number of frames in the local trajectory bit
# last=`$catdcd -num $small_traj | awk '($1=="Total"){print $3}'`


###################################################################
# Prepare local mmgbsa 

cd $main_tmp

echo " "
echo "Task ID : $A"
echo "Host : " `hostname`
echo "Base directory : $current"
echo "Working directory : $main_tmp"
echo "Frames directory : $frames_tmp"

echo " "
echo " Preparing local MMGBSA job ... "
$mmgbsa_path/scripts/prepare_mmgbsa_local.csh $mytraj $first $last $stride $frames_tmp > $current/log/prepare_job_$A.log

###################################################################
# Run local mmgbsa 

echo " Running local MMGBSA job ... "
$mmgbsa_path/scripts/run_one_mmgbsa.sh  >  $current/log/run_job_$A.log


sleep 10

# Keep frames for debug:
#mkdir frames-a.bkp
#cp -rp frames-a/* frames-a.bkp/.
#mkdir frames-b.bkp
#cp -rp frames-b/* frames-b.bkp/.
#mkdir frames-comp.bkp
#cp -rp frames-comp/* frames-comp.bkp/.

echo " Cleaning up ... "
rm -r ./frames-a 
rm -r ./frames-b 
rm -r ./frames-comp 
rm -r ./data

rm -r $frames_tmp

cd $mytmpdir

tar czf $B.tar.gz $B 
rm -r $B
mv $B.tar.gz $current/.

echo "Done."
exit
