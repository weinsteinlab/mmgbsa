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
mmgbsa_path=/users/mcuende1/mmgbsa/mmgbsa2.1/

# Selection for the MMGBSA system
system_selection='protein'

# Selection text for parts A and B of the complex
partA_selection=" chain A "
partB_selection=" chain B "

# Cutoff to choose residues within each part, for which the decomposition will be made. 
# If set to zero, we use the alternative selections below. 
cutoff_residues=0

# Alternatively, one can select residues explicitly for the decomposition.
partA_residues_selection="resid 351 to 353 "
partB_residues_selection="resid 51 to 53 "

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

#    Queuing system (one of "SGE" or "LSF or "SLURM") and queue name
queueing_system="SLURM"
queue_name="normal"
 
# Non-bonded interaction parameters :
#    Cutoff for electro and VdW interactions in Angstroms.  !!! Warning, test with GBMV !!!
cutoff=999 

# Dieclectir constant for solute 
epsilon_s=2.0

#    Monovalent ion concentration in M for Deheye-Huckel screening (default = 0.154). 
ionconc=0.154 

#    Do a membrane calculation: center along Z on group "lipids", and use HDGB in charmm
do_membrane="NO"

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
export queueing_system

source $mmgbsa_path/scripts/setenv.sh

# Name of mmgbsa run
mmgbsa_name="mmgbsa"

# Make the path to traj absolute if it is not already
echo "Locating trajectory ..."
traj=`readlink -f $traj`
if [[ -e $traj ]]; then
        echo "    Using trajectory $traj"
else
        echo "    ERROR : trajectory does not exist"
        echo $traj
        exit 1
fi

# Select the correct resource requirement depending on which cluster we run 
#res_req=""
#if [[  $HOSTNAME =~ panda ]]; then
#    res_req="-l zeno=true,operating_system=rhel6.3"
    # This requests nodes where the /zenodotus file system is mounted
    # and where charmm39 will run (on panda).
#fi

job_name="$(basename $(pwd))_$mmgbsa_name"

###################################################################
# Charmm setup

if [[ -f setup_charmm/data/complex.psf &&  -f setup_charmm/data/complex.crd ]]; then
        echo "Using previous charmm setup in ./setup_charmm/data/ ..."
else
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
fi 

mkdir -p  $mmgbsa_name
cd $mmgbsa_name

###################################################################
# Make vmd_selection.tcl file

echo "Making VMD selection file ..."

cat > vmd_selections.tcl << EOF

# Selection for the whole complex
set complex_sel_text " $system_selection "
# Must be the same as given to setup_charmm.sh 

# Selection text for part A
# transport domain A
set A_sel_text " $partA_selection "

# Selection text for part B
# trimerization domains and transport domains ABC
set B_sel_text " $partB_selection "

# Cutoff to choose residues within each part, for which the decomposition will be made. 
set cutoff_residues $cutoff_residues

# Do membrane calculation with HDGB
set do_membrane $do_membrane

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

$scripts/prepare_mmgbsa_common.sh "$cutoff" "$ionconc" "$epsilon_s"	
if [ $? -ne 0 ]; then
    echo "Error in prepare_mmgbsa_common.sh"
    exit 1
fi


echo "Testing trajectory ... "
mkdir -p test_traj
cd test_traj
# Try to use only the PDB (this is useful when the trajectory comes from gromacs, where there is no psf) 
#mypsf="../data/system.namd.psf"
mypsf="../data/system_raw.pdb"
#mypsf=../system.pdb

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

# SGE :  ----------------------------------------------------------
if [ $queueing_system == "SGE" ]; then 

	jobid_raw=$( qsub -v mmgbsa_path=$mmgbsa_path -v queueing_system=$queueing_system $res_req -q $queue_name -t 1-$n_jobs -tc $max_jobs_running_simultaneously  $parallel_scripts/mmgbsa_master_submit.sh $traj $start_frame $frame_stride $frames_per_job )
	# The -v option to qsub pushes the  environment variables from the shell executing qsub
	# This is needed to pass the mmgbsa_path global variable. 
	jobid=$( echo $jobid_raw | awk '{split($3,jjj,"."); print jjj[1]}' )

        # Post-processing job
        echo "Submitting final post-processing job ... "
        qsub -v mmgbsa_path=$mmgbsa_path -v queueing_system=$queueing_system $res_req -q $queue_name -hold_jid $jobid $parallel_scripts/mmgbsa_final_submit.sh $traj $n_jobs $frames_per_job
        qstat

# LSF :  ----------------------------------------------------------
elif [ $queueing_system == "LSF" ]; then

	jobid_raw=$( bsub -q $queue_name -n 1 -o "mmgbsa2.1.o%J.%I" -e "mmgbsa2.1.e%J.%I"  -J "mmgbsa.[1-$n_jobs]"  " sh $parallel_scripts/mmgbsa_master_submit.sh $traj $start_frame $frame_stride $frames_per_job" )
	echo $jobid_raw
	jobid=$( echo $jobid_raw  | awk '{print substr($2,2,length($2)-2)}' )
	# In LSF, (almost) all environment variables are passed by default.
	# Passing arguments is not as easy, and requires the sub-sh construct. 

        # Post-processing job
        echo "Submitting final post-processing job ... "
        bsub -q $queue_name -n 1 -o "mmgbsa2.1_final.o%J.%I" -e "mmgbsa2.1_final.e%J.%I" -w "done($jobid)" -J "mmgbsa_final" " sh $parallel_scripts/mmgbsa_final_submit.sh $traj $n_jobs $frames_per_job "
        # Passing arguments is not as easy, and requires the sub-sh construct. 
        bjobs

# SLURM :  ----------------------------------------------------------
elif [ $queueing_system == "SLURM" ]; then

        jobid=`sbatch --array=1-${n_jobs}%${max_jobs_running_simultaneously} -p $queue_name --nodes=1 --mem=20G --job-name=$job_name --output="mmgbsa.o%A.%a" --error="mmgbsa.e%A.%a" --export=mmgbsa_path=$mmgbsa_path,queueing_system=$queueing_system $parallel_scripts/mmgbsa_master_submit.sh $traj $start_frame $frame_stride $frames_per_job | egrep -o -e "\b[0-9]+$"`

        # Submit post-processing job
        echo "Submitting final post-processing job ... "
        sbatch --dependency=afterok:${jobid} -p $queue_name --nodes=1 --mem=20G --job-name=${job_name}_final --output="mmgbsa_final.o%A" --error="mmgbsa_final.e%A" --export=mmgbsa_path=${mmgbsa_path},queueing_system=${queueing_system} $parallel_scripts/mmgbsa_final_submit.sh $traj $n_jobs $frames_per_job
	squeue -u `whoami`
else
        echo "ERROR: bad queuing system identifyiner"
	exit 1
fi

exit


