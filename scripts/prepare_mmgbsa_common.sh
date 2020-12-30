#! /bin/bash
# Should be run in directory $system/$mmgbsa_name/
# ./prepare_mmgbsa_common.csh nb_cutoff ionconc
# ARGUMENT : 
# nb_cutoff : cutoff for non-bonded interactions
# ionconc : ion concentration for Debeye-Huckel

pwd

nb_cutoff=$1;
echo "    Cutoff for non-bonded interactions : $nb_cutoff A"

ionconc=${2:-0.154}  # Compact syntax for default value if argument is missing or null
echo "    Monovalent ion concentration for Debye-Huckel : $ionconc M"

eps_s=${3:-1.0}
echo "    Solute dielectric constant : $eps_s "


# The vmd_selections.tcl file must be present.  
if [ !  -f  vmd_selections.tcl ];  then  
    echo "    ERROR! We need a file vmd_selections.tcl in the MMGBSA directory !"
    exit 2
fi 

do_membrane=`awk '($2 == "do_membrane"){print $3}' vmd_selections.tcl`
    
# basedir_backslash=`pwd | awk '{gsub("/","\\/"); print $0}'`
# We need a relative path to loader.str with tmp directories assigned by SGE...
# Also, charmm cannot handle variables with capital letters, so an absolute path
# will fail in some cases. 
basedir_backslash='.' 
system_path="../"

mkdir -p data log outputs

if [ -f data/loader.str ];  then
        echo "    Using previous loader.str"
elif [ -f $system_path/setup_charmm/data/loader.str ]; then
        echo "    Using loaded.str present in ./setup_charmm/data/"
	cp $system_path/setup_charmm/data/loader.str data/.
else
        echo "    Using defalut loader.str from mmgbsa distribution"
        sed "s/BASEDIR/$basedir_backslash/" $inputs/loader.str > data/loader.str
fi

# .......................................................................
# HERE WE USE THE ORIGINAL CHARMM SETUP !

echo "    Copying files to local data directory ..."

cp  -p "$system_path/setup_charmm/data/complex"* data/.
if [[ -f $system_path/setup_charmm/toppar/ligand.par && -f $system_path/setup_charmm/toppar/ligand.rtf ]]; then
	cp -p $system_path/setup_charmm/toppar/ligand.par data/.
        cp -p $system_path/setup_charmm/toppar/ligand.rtf data/.
fi 
cp  -p $system_path/setup_charmm/complex_raw.pdb data/.
#cp -p $system_path/input/*.psf data/system.namd.psf
cp -p $system_path/input/system.pdb data/system_raw.pdb

# We make local copies of charmm input files so that the node does not read 100 times from main disk. 
cp -p $top_path/top_all36_prot.rtf data/.
cp -p $top_path/top_all36_lipid.rtf data/.
cp -p $top_path/top_all36_cgenff.rtf data/.
cp -p $top_path/top_all36_carb.rtf data/.

cp -p $top_path/par_all36_prot.prm data/.
cp -p $top_path/par_all36_lipid.prm data/.
cp -p $top_path/par_all36_cgenff.prm data/.
cp -p $top_path/par_all36_carb.prm data/.

cp -rp $top_path/toppar_water_ions.str data/.
cp -rp $top_path/stream/lipid/toppar_all36_lipid_cholesterol.str data/.
cp -rp $top_path/toppar_all36_lipid_prot.str data/.

# For HDGB membrane
if [ $do_membrane == "YES" ]; then
   echo "    Using HGDB for implicit membrane..." 
   if [ -f $inputs/hdgb_eps.dat ]; then
        cp -rp $inputs/hdgb_eps.dat data/.
   fi
   if [ -f $inputs/hdgb_gamma_switch.dat ]; then
        cp -rp $inputs/hdgb_gamma_switch.dat data/.
   fi
fi

# ..........................................................................
# DEFINITIONS :
echo "    Making definitions ..."

# Reads the specific ./vmd_selections.tcl file
# Makes a definitions.pdb file with flags in the b-factor column.
# Also makes the definitions.str file from scratch. 
$vmd -dispdev text -e $scripts/make_definitions.tcl >& log/make_definitions.log
myerr=`grep ERROR log/make_definitions.log`
if [ "$myerr" != "" ];  then 
	echo $myerr
	exit 1
fi

# Transforms to crd
cat data/definitions.pdb | $scripts/pdb2crd.prl >  data/definitions.crd

# Non-bonded cutoff. 
cuton=$((nb_cutoff - 2)) 
cutnb=$((nb_cutoff + 4))
printf 'SET nbstr ctonnb %d ctofnb %d cutnb %d TRUNC \n\n' $cuton $nb_cutoff $cutnb >> data/definitions.str
# No quotes around the value of nbstr. This would confuse charmm !
printf '!cutoff %d\n\n' $nb_cutoff >> data/definitions.str

# Ion concentration and kappa for Debeye-Huckel term
kappa=` echo "0.316*sqrt( $ionconc ) " | wc -l ` #Debeye screening constant [A-1], 

printf 'SET kappa %6f \n\n' $kappa >> data/definitions.str
printf '!monovalent_ion_concentration %f\n' $ionconc >> data/definitions.str
printf '!solute_dielectric %f\n' $eps_s >> data/definitions.str


# ..........................................................................
# CHARMM RUNS

# Charmm executable
# ln -fs $charmm charmm
 
echo "    Running charmm system.inp ... "
$charmm < $inputs/system.inp > outputs/system.out 
exit_status=$?
if [ $exit_status -ne 0 ]; then
    echo "ERROR : charmm system.inp"
    exit 1
fi


echo "    Running charmm charges.inp ... "
$charmm < $inputs/charges.inp > outputs/charges.out
exit_status=$?
if [ $exit_status -ne 0 ]; then
    echo "ERROR : charmm charges.inp"
    exit 1
fi





