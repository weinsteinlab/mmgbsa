
# MMGBSA distribution
export mmgbsa_path=/home/mcuendet/mmgbsa/mmgbsa2.1
export scripts=$mmgbsa_path/scripts/
export parallel_scripts=$mmgbsa_path/parallel_scripts/
export inputs=$mmgbsa_path/charmm_inputs/
export perl_scripts=$mmgbsa_path/perl_scripts/
export top_path=$mmgbsa_path/top_files_mackerell/

# Scratch directory
export scratch_path="/tmp/$USER/mmgbsa/"

# Executatbles
export charmm=/home/vzoete/charmm/c36b1/exec/em64t/charmm

export vmd=/home/mcuendet/local/vmd-1.9.2/bin/vmd
# Fido has an old version of perl, which does not understand some operators.
export perl=`which perl`

