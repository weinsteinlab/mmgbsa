#! /bin/tcsh -f
# Should be run in directory $system/$mmgbsa_name/
# ./prepare_mmgbsa_common.csh nb_cutoff ionconc
# ARGUMENT : 
# nb_cutoff : cutoff for non-bonded interactions
# ionconc : ion concentration for Debeye-Huckel

pwd

set nb_cutoff = $1;
echo "    Cutoff for non-bonded interactions : $nb_cutoff A"

set ionconc = $2
if ( $ionconc == "" ) then 
	set ionconc = 0.154
endif
echo "    Monovalent ion concentration for Debye-Huckel : $ionconc M"

# The vmd_selections.tcl file must be present.  
if ( ! ( -e  vmd_selections.tcl ) )  then  
    echo "    ERROR! We need a file vmd_selections.tcl in the MMGBSA directory !"
    exit 2
endif 
    
# paths ( now read from environment variables )
#set scratch_path="/scratch/mac2109/mmgbsa/"
#set scratch_path="/tmp/$USER/mmgbsa/"
#set top_path="/home/mac2109/top_files/mackerell/"
#set mmgbsa_path="/home/mac2109/mmgbsa/mmgbsa2.0/"
# set inputs=$mmgbsa_path/charmm_inputs/
# The path to the main mmgbsa directory where the ./setup_charmm/ directory is located
#set main_path=".."a

# set basedir_backslash=`pwd | awk '{gsub("/","\\/"); print $0}'`
# We need a relative path to loader.str with tmp directories assigned by SGE...
# Also, charmm cannot handle variables with capital letters, so an absolute path
# will fail in some cases. 
set  basedir_backslash='.' 

mkdir -p data log outputs

if ( -e data/loader.str ) then
        echo "    Using previous loader.str"
else
        sed "s/BASEDIR/$basedir_backslash/" $inputs/loader.str > data/loader.str
endif

# .......................................................................
# HERE WE USE THE ORIGINAL CHARMM SETUP !
cp  -p $system_path/setup_charmm/data/complex* data/.
cp  -p $system_path/setup_charmm/complex_raw.pdb data/.
#cp -p $system_path/input/*.psf data/system.namd.psf
cp -p $system_path/input/*.pdb data/system.namd.pdb

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

# ..........................................................................
# DEFINITIONS :
echo "    Making definitions ..."

# Reads the specific ./vmd_selections.tcl file
# Makes a definitions.pdb file with flags in the b-factor column.
# Also makes the definitions.str file from scratch. 
$vmd -dispdev text -e $scripts/make_definitions.tcl >& log/make_definitions.log
set myerr=`grep ERROR log/make_definitions.log`
if ( "$myerr" != "" ) then 
	echo $myerr
	exit 1
endif

# Transforms to crd
cat data/definitions.pdb | $scripts/pdb2crd.prl >  data/definitions.crd

# Non-bonded cutoff. 
@ cuton = $nb_cutoff - 2 
@ cutnb = $nb_cutoff + 4

printf 'SET nbstr ctonnb %d ctofnb %d cutnb %d TRUNC \n\n' $cuton $nb_cutoff $cutnb >> data/definitions.str
# No quotes around the value of nbstr. This would confuse charmm !
printf '\!cutoff %d\n\n' $nb_cutoff >> data/definitions.str

# Ion concentration and kappa for Debeye-Huckel term
set kappa=` echo "0.316*sqrt( $ionconc ) " | bc -l ` #Debeye screening constant [A-1], 

printf 'SET kappa %6f \n\n' $kappa >> data/definitions.str
printf '\!monovalent_ion_concentration %f\n' $ionconc >> data/definitions.str


# ..........................................................................
# CHARMM RUNS

# Charmm executable
# ln -fs $charmm charmm
 
echo "    Running charmm system.inp ... "
$charmm < $inputs/system.inp > outputs/system.out 
if ($? != 0) then
    echo "ERROR : charmm system.inp"
    exit 1
endif


echo "    Running charmm charges.inp ... "
$charmm < $inputs/charges.inp > outputs/charges.out
if ($? != 0) then
    echo "ERROR : charmm charges.inp"
    exit 1
endif





