#! /bin/bash

# Needs a directory ./input with *.psf and *.pdb files

set -e
set -u

###################################################################
#                                                                 #
# User-defined parameters                                         #
#                                                                 #
###################################################################

# Path to MMGBSA distribution 
mmgbsa_path=/home/mac2109/mmgbsa/mmgbsa2.1/

# Selection for the MMGBSA system
system_selection='protein'

# Selection text for parts A and B of the complex
partA_selection=" chain A "
partB_selection=" chain B "

# Cutoff to choose residues within each part, for which the decomposition will be made. 
# If set to zero, we use the alternative selections below. 
cutoff_residues=0

# Alternatively, one can select residues explicitly for the decomposition.
partA_residues_selection="chain A and resid 351 to 353 "
partB_residues_selection="chain B and resid 51 to 53 "

# Trajectory of the full system (can be a DCD file or an XTC file). 
traj=/path/to/traj.xtc

# Frames used :
start_frame=1
frame_stride=1

# Parallelization settings :
#    number of frames in each sub-job.
frames_per_job=10
#    number of sub-jobs. Together with $frames_per_job, determines the total number of frames.
n_jobs=3
#    Maximum number of jobs junning simultaneourly, in order not to invate an entire cluter.
max_jobs_running_simultaneously=50   

# Non-bonded interaction parameters :
#    Cutoff for electro and VdW interactions in Angstroms.
cutoff=30
#    Monovalent ion concentration in M for Deheye-Huckel screening (default = 0.154). 
ionconc=0.154 

# System details - proteins are assumed to come first in the PSF.
#    Number of separate (i.e. not covalently bonded) protein/peptide segments
proteins=3 

# For each protein/peptide, include the following variables ###
capping[1]=0 # is the first protein/peptide's n-term capped? 0 for no, 1 for yes. 
capping[2]=0 # is the first protein/peptide's c-term capped? 0 for no, 1 for yes.

capping[3]=0 # is the 2nd protein/peptide's n-term capped? 0 for no, 1 for yes. 
capping[4]=0 # is the 2nd protein/peptide's c-term capped? 0 for no, 1 for yes.

capping[5]=0 # is the 3rd protein/peptide's n-term capped? 0 for no, 1 for yes. 
capping[6]=0 # is the 3rd protein/peptide's c-term capped? 0 for no, 1 for yes.
# et caetera ...


###################################################################
#                                                                 #
# End of user-defined parameters                                  #
#                                                                 #
###################################################################


###################################################################
# Define some variables 

export mmgbsa_path  
# It is very important that mmgbsa_path be a global variable.

source $mmgbsa_path/scripts/setenv.sh

# Name of mmgbsa run
mmgbsa_name="mmgbsa"

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
    res_req="-l zeno=true,operating_system=rhel6.3"
    # This requests nodes where the /zenodotus file system is mounted
    # and where charmm39 will run (on panda).
fi


###################################################################
# Charmm setup

echo "Performing charmm setup ... "

mkdir -p setup_charmm
cd setup_charmm

$scripts/setup_charmm.sh "${system_selection}" "$proteins" "${capping[@]}" | tee setup_charmm.log 

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

echo "Making VMD selection file ..."

cat > vmd_selections.tcl << EOF

# Selection for the whole complex
set complex_sel_text " $system_selection "
# Must be the same as given to setup_charmm.csh 

# Selection text for part A
# transport domain A
set A_sel_text " $partA_selection "

# Selection text for part B
# trimerization domains and transport domains ABC
set B_sel_text " $partB_selection "

# Cutoff to choose residues within each part, for which the decomposition will be made. 
set cutoff_residues $cutoff_residues

EOF

# There are two possibilities for the definition of residues of interest. 
# 1) If a cutoff has been defined :
if [ $cutoff_residues -gt 0 ]; then

cat >> vmd_selections.tcl << EOF

# Selection text for interesting residues of part A
set Aresidues_sel_text  " ( \$A_sel_text ) and same residue as within \$cutoff_residues of ( \$B_sel_text ) "

# Selection text for interesting residues of part B
set Bresidues_sel_text  " ( \$B_sel_text ) and same residue as within \$cutoff_residues of ( \$A_sel_text ) "

EOF

else
# 2) with explicit residue selections :
cat >> vmd_selections.tcl << EOF

# Selection text for interesting residues of part A
set Aresidues_sel_text  "( \$A_sel_text ) and ( $partA_residues_selection )"

# Selection text for interesting residues of part B
set Bresidues_sel_text  " ( \$B_sel_text ) and ( $partB_residues_selection )"

EOF

fi


###################################################################
# Prepare mmgbsa (part common to all subjobs)

echo "Preparing MMGBSA directory ... "

$scripts/prepare_mmgbsa_common.csh "$cutoff" "$ionconc"	


echo "Testing trajectory ... "
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
	echo "See file ./mmgbsa/log/test_traj.log"
	exit 1
fi
cd ..

###################################################################
# Submit sub-jobs with the parallel script
#      This calls the preparation script 
#      $scripts/prepare_mmgbsa_local.csh $traj $startframe $endframe $stride

echo "Submitting all sub-jobs ... "

jobid_raw=$( qsub -v mmgbsa_path=$mmgbsa_path $res_req  -t 1-$n_jobs -tc $max_jobs_running_simultaneously  $parallel_scripts/mmgbsa_master_submit.sh $traj $start_frame $frame_stride $frames_per_job )
# The -v option to qsub pushes the  environment variables from the shell executing qsub
# This is needed to pass the mmgbsa_path global variable. 

jobid=$( echo $jobid_raw | awk '{split($3,jjj,"."); print jjj[1]}' )

###################################################################
# Submit post-processing job

echo "Submitting final post-processing job ... "

if [ $frames_per_job -lt 100 ]
then
	qsub -v mmgbsa_path=$mmgbsa_path  $res_req -hold_jid $jobid $parallel_scripts/mmgbsa_final_submit.sh $traj $n_jobs $frames_per_job 
else
        qsub -v mmgbsa_path=$mmgbsa_path  $res_req -hold_jid $jobid $parallel_scripts/mmgbsa_final_submit_more_frames.sh $traj $n_jobs $frames_per_job
fi

qstat
exit






