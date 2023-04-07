#! /bin/bash -l

# MMGBSA distribution
export mmgbsa_path=/absolute/path/to/parent/mmgbsa
export scripts=$mmgbsa_path/scripts/
export parallel_scripts=$mmgbsa_path/parallel_scripts/
export inputs=$mmgbsa_path/charmm_inputs/
export perl_scripts=$mmgbsa_path/perl_scripts/
export top_path=$mmgbsa_path/top_files_mackerell/

# Scratch directory
export scratch_path="/tmp/$USER/mmgbsa/"

# Executatbles
if [[  $HOSTNAME =~ panda ]] || [[  $HOSTNAME =~ curie ]] || [[ $HOSTNAME =~ edison ]] ; then
    export charmm=/athena/hwlab/scratch/lab_data/software/charmm/charmm_edison/charmm/exec/gnu/charmm 
    export vmd=/athena/hwlab/scratch/lab_data/software/vmd/vmd-1.9.3_athena/install_bin/vmd_athena
    export perl=`which perl`
fi

if [[  $HOSTNAME =~ wally ]] || [[ $HOSTNAME =~ axiom ]] ; then
    export charmm=/users/mcuende1/local/c44b1/bin/charmm 
    export vmd=/users/mcuende1/local/vmd-1.9.3/bin/vmd
    export perl=`which perl`
fi
