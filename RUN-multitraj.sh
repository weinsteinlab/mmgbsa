#! /bin/bash -l

# Needs a directory ./input with *.psf and *.pdb files

set -e
set -u

###################################################################
#                                                                 #
# User-defined parameters                                         #
#                                                                 #
###################################################################

# Path to MMGBSA distribution 
mmgbsa_path=/home/mac2109/mmgbsa/mmgbsa2.2/

# Selection for the MMGBSA system
system_selection='protein'

# Select residues explicitly for the decomposition.
residue_selection="chain A and resid 351 to 353 "

# Trajectory of the full system (can be a DCD file or an XTC file). 
traj=/path/to/traj.xtc

# Frames used 
start_frame=1
frame_stride=1

# Number of jobs
frames_per_job=10 # number of frames in each sub-job
n_jobs=3
max_jobs_running_simultaneously=50

# Non-bonded interaction parameters
cutoff=30	# Cutoff for electro and VdW interactions in Angstroms
ionconc=0.154   # Monovalent ion concentration in M (default = 0.154). 

# System details - proteins are assumed to come first in the PSF.
proteins=2 # number of separate (i.e. not covalently bonded) protein/peptide segments 

# For each protein/peptide, include the following variables ###
capping[1]=0 # is the first protein/peptide's n-term capped? 0 for no, 1 for yes. 
capping[2]=0 # is the first protein/peptide's c-term capped? 0 for no, 1 for yes.

capping[3]=0 # is the first protein/peptide's n-term capped? 0 for no, 1 for yes. 
capping[4]=0 # is the first protein/peptide's c-term capped? 0 for no, 1 for yes.

capping[5]=0 # is the first protein/peptide's n-term capped? 0 for no, 1 for yes. 
capping[6]=0 # is the first protein/peptide's c-term capped? 0 for no, 1 for yes.

capping[7]=0 # is the first protein/peptide's n-term capped? 0 for no, 1 for yes. 
capping[8]=0 # is the first protein/peptide's c-term capped? 0 for no, 1 for yes.

capping[9]=0 # is the first protein/peptide's n-term capped? 0 for no, 1 for yes. 
capping[10]=0 # is the first protein/peptide's c-term capped? 0 for no, 1 for yes.

capping[11]=0 # is the first protein/peptide's n-term capped? 0 for no, 1 for yes. 
capping[12]=0 # is the first protein/peptide's c-term capped? 0 for no, 1 for yes.
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
    res_req="-l h_vmem=2G"
    # This required argment requests memory
fi

# Variables for compatibility with one-traj code.
partA_selection=$system_selection
partA_residues_selection=$residue_selection

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

# Definition of residues of interest. 
cat >> vmd_selections.tcl << EOF

# Selection text for interesting residues of part A
set Aresidues_sel_text  "( \$A_sel_text ) and ( $partA_residues_selection )"

# Selection text for interesting residues of part B
set Bresidues_sel_text  " ( \$B_sel_text ) and ( $partB_residues_selection )"

EOF

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
	echo "See file ./log/test_traj.log"
	exit 1
fi
cd ..

###################################################################
# Submit sub-jobs with the parallel script
#      This calls the preparation script 
#      $scripts/prepare_mmgbsa_local.csh $traj $startframe $endframe $stride

echo "Submitting all sub-jobs ... "

jobid_raw=$( qsub -v mmgbsa_path=$mmgbsa_path $res_req  -t 1-$n_jobs -tc $max_jobs_running_simultaneously  $parallel_scripts/mmgbsa_master_submit_multitraj.sh $traj $start_frame $frame_stride $frames_per_job )
# The -v option to qsub pushes the  environment variables from the shell executing qsub
# This is needed to pass the mmgbsa_path global variable. 

jobid=$( echo $jobid_raw | awk '{split($3,jjj,"."); print jjj[1]}' )

###################################################################
# Submit post-processing job

echo "Submitting final post-processing job ... "

qsub -v mmgbsa_path=$mmgbsa_path  $res_req -hold_jid $jobid $parallel_scripts/mmgbsa_final_submit_multitraj.sh $traj $n_jobs $frames_per_job

qstat
exit





