
# MMGBSA distribution
export mmgbsa_path=/home/mac2109/mmgbsa/mmgbsa2.1
export scripts=$mmgbsa_path/scripts/
export parallel_scripts=$mmgbsa_path/parallel_scripts/
export inputs=$mmgbsa_path/charmm_inputs/
export perl_scripts=$mmgbsa_path/perl_scripts/
export top_path=$mmgbsa_path/top_files_mackerell/

# Scratch directory
export scratch_path="/tmp/$USER/mmgbsa/"

# Executatbles
export charmm=/home/mac2109/local/charmm36a2_intel9_64_mpich-1.2.7p1/bin/charmm
#export charmm=/home/mac2109/src/c39b2/exec/em64t/charmm
export vmd=/home/mac2109/local/vmd-1.9.2/bin/vmd 
# Fido has an old version of perl, which does not understand some operators.
export perl=/home/mac2109/local/perl-5.24.0/bin/perl

