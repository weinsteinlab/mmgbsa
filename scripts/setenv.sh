#! /bin/bash -l

# MMGBSA distribution
export mmgbsa_path=/athena/hwlab/scratch/des2037/NSP5/openMM/mmgbsa
export scripts=$mmgbsa_path/scripts/
export parallel_scripts=$mmgbsa_path/parallel_scripts/
export inputs=$mmgbsa_path/charmm_inputs/
export perl_scripts=$mmgbsa_path/perl_scripts/
export top_path=$mmgbsa_path/top_files_mackerell/

# Scratch directory
export scratch_path="/tmp/$USER/mmgbsa/"

# Executatbles
if [[  $HOSTNAME =~ pug ]]; then
    export charmm=/home/mac2109/local/charmm36a2_intel9_64_mpich-1.2.7p1/bin/charmm
    # This works on fido but gets killed on the panda front end 
    export vmd=/home/mac2109/local/vmd-1.9.2/bin/vmd 
    # Fido has an old version of perl, which does not understand some operators.
    export perl==/home/mac2109/local/perl-5.24.0/bin/perl    
fi
if [[  $HOSTNAME =~ panda ]] || [[  $HOSTNAME =~ curie ]] || [[ $HOSTNAME =~ edison ]] ; then
    #export charmm=/home/mac2109/local/c44b1/bin/charmm 
    export charmm=/athena/hwlab/scratch/lab_data/software/charmm/charmm_edison/charmm/exec/gnu/charmm 
    # This works on panda but is too recent for fido
    export vmd=/athena/hwlab/scratch/lab_data/software/vmd/vmd-1.9.3_athena/install_bin/vmd_athena
    export perl=`which perl`
fi
if [[  $HOSTNAME =~ wally ]] || [[ $HOSTNAME =~ axiom ]] ; then
    export charmm=/users/mcuende1/local/c44b1/bin/charmm 
    export vmd=/users/mcuende1/local/vmd-1.9.3/bin/vmd
    export perl=`which perl`
fi
