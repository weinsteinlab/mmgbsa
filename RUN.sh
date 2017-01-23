#! /bin/bash

# Needs a directory ./input with *.psf and *.pdb files

set -e
set -u

###################################################################
#                                                                 #
# User-defined parameters                                         #
#                                                                 #
###################################################################

# Selection for the MMGBSA system
system_selection='protein or (chain S T U L M N and not lipid)'

# Selection text for part A
partA_selection=" chain A and ( (resid 223 to 417) or (chain S L and not lipid) ) "

# Selection text for part B
partB_selection="  chain A and (resid 34 to 74)  "

# Cutoff to choose residues within each part, for which the decomposition will be made. 
# If set to zero, we use the alternative selections below. 
cutoff_residues=0

# Alternatively, one can choose residues explicitly
partA_residues_selection="chain A and resid 351 to 353 "
partB_residues_selection="chain A and resid 51 to 53 "

# Trajectory of the full system (can be a DCD file or an XTC file). 
traj=/home/mac2109/mod/gltph/new.c36/dyna/systems/ofcc2/equil_phase4_unscaled/ofcc2.xtc

# Frames used 
start_frame=1
frame_stride=1

# Number of jobs
frames_per_job=10 # number of frames in each sub-job
n_jobs=3

# Non-bonded interaction parameters
cutoff=30	# Cutoff for electro and VdW interactions in Angstroms
ionconc=0.154   # Monovalent ion concentration in M (default = 0.154). 

# System details
proteins=6 # number of separate (i.e. not covalently bonded) proteins/peptides

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

mmgbsa_path=/home/mac2109/mmgbsa/mmgbsa2.1/
source $mmgbsa_path/scripts/setenv.sh

# Name of mmgbsa run
mmgbsa_name="mmgbsa"


###################################################################
# Charmm setup

echo "Performing charmm setup ... "

mkdir -p setup_charmm
cd setup_charmm

$scripts/setup_charmm.sh "${system_selection}" "$proteins" "${capping[@]}" > setup_charmm.log

is_ok=`grep  "Everything seems Ok" setup_charmm.log`
echo $is_ok
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

###################################################################
# Submit sub-jobs with the parallel script
#      This calls the preparation script 
#      $scripts/prepare_mmgbsa_local.csh $mytraj $startframe $endframe $stride

echo "Submitting all sub-jobs ... "

jobid_raw=$( qsub -t 1-$n_jobs $parallel_scripts/mmgbsa_master_submit.sh $traj $start_frame $frame_stride $frames_per_job )

jobid=$( echo $jobid_raw | awk '{split($3,jjj,"."); print jjj[1]}' )

###################################################################
# Submit post-processing job

echo "Submitting final post-procession job ... "

qsub -hold_jid $jobid $parallel_scripts/mmgbsa_final_submit.sh $traj $n_jobs $frames_per_job 









