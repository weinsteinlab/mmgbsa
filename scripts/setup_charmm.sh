#! /bin/bash


# Does a CHARMM setup with the charmm36 force field
# Usage ./setup_charmm.csh  selection_text protein_num "$capping$
# 
# ARGUMENTS :
# 	selection_text	: Selection text to remove solvent
#	protein_num	: Number of proteins in the system
# 	capping		: Array with caping option for each segment
#
# Only charged terminal groups are available in automatic setup,
# otherwise manual editing is required

set -e
set -u
# source ./setenv.sh

# -------------------------------------------------------------
# Read arguments 

# Selection text to remove solvent
complex_sel_text=`echo $1` 

# Number of proteins in the system
protein_num=`echo $2`
shift 2		# This renumbers arguments

# Capping flags
capping=( "$@" )
echo "Capping options : ${capping[*]}"

# ---------------------------------------------------------------
# Make directory structure
 mkdir -p setup_charmm
 cd setup_charmm
 pwd

 mkdir -p data
 #ln -fs $charmm_toppar/top_all36_prot.rtf .
 #ln -fs $charmm_toppar/par_all36_prot.prm .

 # Make links with generic names 
 ln -fs ../input/*.pdb system.pdb
 ln -fs ../input/*.psf system.namd.psf

# DEREK : Change cholesterol name 
#sed -i 's/CHL1/CLOL/' system.namd.psf system.pdb

# ---------------------------------------------------------------
 # Extract complex from full system in NAMD format:
echo "Extracting complex ..."
cat > extract_complex.tcl  << EOF
  mol new system.namd.psf
  mol addfile system.pdb
  set sel [atomselect top "$complex_sel_text" ]
  \$sel writepdb complex_raw.pdb
  \$sel writepsf complex_raw.psf
  set nn [\$sel num]
  puts "There are \$nn atoms in the selection"
  quit
EOF

$vmd -dispdev text -e  extract_complex.tcl >& extract_complex.log

# Convert to crd
cat complex_raw.pdb | $scripts/pdb2crd.prl > complex_raw.crd

# Parse protein and check if OK. 
echo "Parsing complex ..."
$scripts/parse-protein.prl complex_raw.crd

#echo " Is this ok? If not, edit the ./preparing-system/ProteinSegments file before hitting enter"
#set continue = $< 

# ---------------------------------------------------------------
# Modify ProteinSegments for capping. 

for ii in `seq 1 $protein_num`; do
	j1=$(( (ii-1) * 2 ))
	j2=$(( j1 + 1 ))
	if [[ ${capping[j1]} -eq 1 ]]; then
		sed -i -e "$ii,$ii s/NTER/ACE /" ./preparing-system/ProteinSegments
	fi
	if [[ ${capping[j2]} -eq 1 ]]; then
		sed -i -e "$ii,$ii s/CTER/CT2 /" ./preparing-system/ProteinSegments
	fi
done

prot_plus=$(( protein_num + 1))

sed -i -e "$prot_plus,9999 s/NTER/NONE/" ./preparing-system/ProteinSegments
sed -i -e "$prot_plus,9999 s/CTER/NONE/" ./preparing-system/ProteinSegments

echo ""
cat preparing-system/ProteinSegments
echo ""

# ---------------------------------------------------------------
# Do the charmm setup 

echo " Preparing charmm setup ... "
$perl $scripts/prepare-charmm36.prl
 
cd ..

#end
