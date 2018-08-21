#! /bin/bash -l

# Needs a directory ./input with *.psf and *.pdb files

#set -e
set -u

###################################################################
#                                                                 #
# User-defined parameters                                         #
#                                                                 #
###################################################################

echo "    Starting ..."

# Path to MMGBSA distribution 
mmgbsa_path=/home/mcuendet/archive/mmgbsa/mmgbsa-multitraj/

# Name of mmgbsa run (will correspond to sub-directory of same name)
mmgbsa_name="mmgbsa_A"
#mmgbsa_name="mmgbsa_B"
#mmgbsa_name="mmgbsa_AB"

# Selection for the MMGBSA system
system_selection='protein or (chain S T U L M N and not lipid)'

# Selection for the part of the system
# part_selection=" ( chain A and ( resid 223 to 417)) or (chain S L and not lipid) "
# part_selection=" chain A and (resid 34 to 74)  "
# part_selection=" ( chain A and  (resid 34 to 74 223 to 417)) or (chain S L and not lipid) "
# FOR COMPATIBILITY :
 part_selection=" chain A and ( resid 223 to 417) "
# part_selection=" chain A and (resid 34 to 74)  "
# part_selection=" chain A and  (resid 34 to 74 223 to 417) "

# Select residues explicitly for the decomposition.
 residue_selection="chain A and resid 351 to 353 "
# residue_selection="chain A and resid 51 to 53 "
# residue_selection="chain A and resid 51 to 53 351 to 353 "

# Trajectory of the full system (can be a DCD file or an XTC file). 
traj=$mmgbsa_path/example/input/ofcc2.xtc

# Frames used 
start_frame=1
frame_stride=1

# Parallelization settings :
#    number of frames in each sub-job.
frames_per_job=10
#    number of sub-jobs. Together with $frames_per_job, determines the total number of frames.
n_jobs=3
#    Maximum number of jobs junning simultaneourly, in order not to invate an entire cluter.
max_jobs_running_simultaneously=50  
#    Queuing system (one of "SGE" or "LSF") and queue name  
queueing_system="LSF"
queue_name="3dmodel-big"  

# Non-bonded interaction parameters :
#    Cutoff for electro and VdW interactions in Angstroms.
cutoff=30
#    Monovalent ion concentration in M for Deheye-Huckel screening (default = 0.154). 
ionconc=0.154 

# System details - proteins are assumed to come first in the PSF.
#    Number of separate (i.e. not covalently bonded) protein/peptide segments
proteins=6 

# For each protein/peptide, include the following variables ###
capping[1]=0 # is the first protein/peptide's n-term capped? 0 for no, 1 for yes. 
capping[2]=0 # is the first protein/peptide's c-term capped? 0 for no, 1 for yes.

capping[3]=0 # is the 2nd protein/peptide's n-term capped? 0 for no, 1 for yes. 
capping[4]=0 # is the 2nd protein/peptide's c-term capped? 0 for no, 1 for yes.

capping[5]=0 # is the 3rd protein/peptide's n-term capped? 0 for no, 1 for yes. 
capping[6]=0 # is the 3rd protein/peptide's c-term capped? 0 for no, 1 for yes.
# et caetera ...

capping[7]=0
capping[8]=0
capping[9]=0
capping[10]=0
capping[11]=0
capping[12]=0


###################################################################
#                                                                 #
# End of user-defined parameters                                  #
#                                                                 #
###################################################################


###################################################################
# Define some variables 

echo "    Defining environment ... "
export mmgbsa_path  
# It is very important that mmgbsa_path be a global variable.
export queueing_system

source $mmgbsa_path/scripts/setenv.sh

# Make the path to traj absolute if it is not already
traj=`readlink -f $traj`
if [[ -e $traj ]]; then
        echo "Using trajectory $traj"
else
        echo "ERROR : trajectory does not exist"
        echo $traj
        exit 1
fi

# Select the correct resource requirement depending on which cluster we run 
res_req=""
if [[  $HOSTNAME =~ panda ]]; then
    res_req="-l h_vmem=2G"
    # This required argment requests memory
fi

# Variables for compatibility with one-traj code.
#partA_selection=$system_selection
#partA_residues_selection=$residue_selection

###################################################################
# Charmm setup

echo "    Performing charmm setup ... "

mkdir -p setup_charmm
cd setup_charmm

#$scripts/setup_charmm.sh "${system_selection}" "$proteins" "${capping[@]}" | tee setup_charmm.log 
echo "          SKIPPING ...    "

is_ok=`grep  "Everything seems Ok" setup_charmm.log`
if [ -z "$is_ok" ]; then
	echo "ERROR during charmm setup !"
	exit 1
fi

cd ..
mkdir -p  $mmgbsa_name
cd $mmgbsa_name

###################################################################
# Make vmd_selection.tcl file

echo "    Making VMD selection file ..."

cat > vmd_selections.tcl << EOF

# Selection for the whole complex
set complex_sel_text " $system_selection "
# Must be the same as given to setup_charmm.csh 

# Selection text for part A (still necessary in multitraj for compatibility reasons)
set A_sel_text " $part_selection "

# Selection text for interesting residues
set Aresidues_sel_text  "( \$complex_sel_text ) and ( $residue_selection )"

EOF

###################################################################
# Prepare mmgbsa (part common to all subjobs)

echo "    Preparing MMGBSA directory ... "

$scripts/prepare_mmgbsa_common_multitraj.csh "$cutoff" "$ionconc"	

echo "    Testing trajectory ... "
mkdir -p test_traj
cd test_traj
mypsf="../data/system.namd.psf"

cat > test_traj.tcl  << EOF
  source ../vmd_selections.tcl
  mol new $mypsf
  mol addfile $traj waitfor all last 2
  quit
EOF
$vmd -dispdev text -e test_traj.tcl >& ../log/test_traj.log
if [ "`grep ERROR ../log/test_traj.log`" != "" ]; then
	echo "ERROR with trajectory !"
	echo "See file ./log/test_traj.log"
	exit 1
fi
cd ..

###################################################################
# Submit sub-jobs with the parallel script
#      This calls the preparation script 
#      $scripts/prepare_mmgbsa_local.csh $traj $startframe $endframe $stride

echo "    Submitting all sub-jobs ... "

# SGE : 
if [ $queueing_system == "SGE" ]; then 
	jobid_raw=$( qsub -v mmgbsa_path=$mmgbsa_path -v queueing_system=$queueing_system $res_req -q $queue_name -t 1-$n_jobs -tc $max_jobs_running_simultaneously  $parallel_scripts/mmgbsa_master_submit_multitraj.sh $traj $start_frame $frame_stride $frames_per_job )
	# The -v option to qsub pushes the  environment variables from the shell executing qsub
	# This is needed to pass the mmgbsa_path global variable. 
	jobid=$( echo $jobid_raw | awk '{split($3,jjj,"."); print jjj[1]}' )
fi

# LSF :
if [ $queueing_system == "LSF" ]; then
	jobid_raw=$( bsub -q $queue_name -n 1 -o "mmgbsa2.1.o%J.%I" -e "mmgbsa2.1.e%J.%I"  -J "mmgbsa.[1-$n_jobs]"  " sh $parallel_scripts/mmgbsa_master_submit_multitraj.sh $traj $start_frame $frame_stride $frames_per_job" )
	echo $jobid_raw
	jobid=$( echo $jobid_raw  | awk '{print substr($2,2,length($2)-2)}' )
	# In LSF, (almost) all environment variables are passed by default.
	# Passing arguments is not as easy, and requires the sub-sh construct. 
fi

###################################################################
# Submit post-processing job

echo "    Submitting final post-processing job ... "

# SGE : 
if [ $queueing_system == "SGE" ]; then
	qsub -v mmgbsa_path=$mmgbsa_path -v queueing_system=$queueing_system $res_req -q $queue_name -hold_jid $jobid $parallel_scripts/mmgbsa_final_submit_multitraj.sh $traj $n_jobs $frames_per_job 
 	qstat
fi

# LSF :
if [ $queueing_system == "LSF" ]; then
	bsub -q $queue_name -n 1 -o "mmgbsa2.1_final.o%J.%I" -e "mmgbsa2.1_final.e%J.%I" -w "done($jobid)" -J "mmgbsa_final" " sh $parallel_scripts/mmgbsa_final_submit_multitraj.sh $traj $n_jobs $frames_per_job "
	# Passing arguments is not as easy, and requires the sub-sh construct. 
	bjobs
fi

exit





