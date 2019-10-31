#! /bin/bash 
# Should be run in directory $system/$mmgbsa_name/
# ./prepare_mmgbsa_local.csh traj_dir startframe endframe stride
# ARGUMENT : 
# traj_dir: path to the trajectory.
# startframe : first frame
# endframe : last frame
# stride : frame stride

set -e
set -u

# -------------------------------------------------------------
# Read arguments 

# relative path to the directory with trajectory.
#set traj_dir=$1
# File name for trajectories
trajname=$1

# time interval between frames :
startframe=$2
endframe=$3
stride=$4

# Paths
frames_tmp=$5

#scratch_path="$frames_tmp/$USER/mmgbsa/"
scratch_path=$frames_tmp
echo "Scratch path will be : $scratch_path"

pwd

# Prepare directory where to run the analysis.
basedir=`pwd`
basename=`pwd | sed 's/\//+/g' `
basedir_backslash=`pwd | awk '{gsub("/","\\/"); print $0}'`
#basedir_backslash=`pwd | awk '{gsub("\/","\\\/"); print $0}'` # This generates warnings on some machines.
rundir="$scratch_path/$basename"	
echo $rundir > rundir

mkdir -p outputs total inter log solv-a solv-b solv-comp sas-a sas-b sas-comp

if [ ! -f data/loader.str ]; then
        echo "ERROR : We need a ./data directory with a loader.str file"
	exit 1
fi

if [ ! -f data/definitions.str ]; then
        echo "ERROR : We need a ./data directory with a definitions.str file"
	exit 1
fi


# .......................................................................
# PREPARE DIRECTORIES

# Prepare frames directly on /scratch
basedir=`pwd`
echo $basedir > basedir
# Specific basename for cases where the scratch directory is common. 
basename=`pwd | sed 's/\//+/g' `

framesdir=$scratch_path$basename'_frames-comp'	
echo $framesdir > framesdir
rm -rf  $framesdir  frames-comp      
mkdir -p $framesdir
ln -s $framesdir frames-comp
echo framesdir : $framesdir

# The two following directories will be filled by charmm scripts 
# and accessed by perl scripts
framesdir_a=$scratch_path$basename'_frames_a'	
echo $framesdir_a > framesdir_a
rm -rf  $framesdir_a  frames-a      
mkdir -p $framesdir_a
ln -s $framesdir_a frames-a
echo framesdir_a : $framesdir_a

framesdir_b=$scratch_path$basename'_frames_b'	
echo $framesdir_b > framesdir_b
rm -rf  $framesdir_b  frames-b      
mkdir -p $framesdir_b
ln -s $framesdir_b frames-b
echo framesdir_b : $framesdir_b

# ..........................................................................
# FRAME EXTRACTION
#
echo " Extracting frames ..."
#mypsf="./data/system.namd.psf"
mypsf="./data/system.namd.pdb"

cat > extract_frames.tcl  << EOF
  source ./vmd_selections.tcl
  mol new $mypsf
  # When using a pdb file for topology, we have to delete the coordinates before loading the trajectory!!
  animate delete all

  mol addfile $trajname waitfor all

  set nf [molinfo top get numframes]
  set sel [atomselect top "\$complex_sel_text"]

  # If we do membrane calculations, we have to center membrane at Z=0
  if { \$do_membrane == "YES" } {
      puts "Will center the membrane at Z=0"
      set membrane_sel_text "lipids and noh"
      set membrane [ atomselect top \$membrane_sel_text ]
  }
  
  if {$endframe > \$nf} {
     error "End frame specified is beyond trajectory end !!"
  }

  set j 1
  for {set i $startframe} {\$i <= $endframe} {incr i $stride} {
    set frameidx [ expr {\$i -1 }]
    \$sel frame \$frameidx
    # If we do membrane calculation
    if { \$do_membrane == "YES" } {
        \$membrane frame \$frameidx
        set mem_com [measure center \$membrane]
	set mem_z [lindex \$mem_com 2]
        puts "Original membrane Z : \$mem_z"
        set offset [ expr { -\$mem_z } ]
        \$sel move [transoffset "0 0 \$offset" ]     
    }
    \$sel writepdb "frames-comp/\$j-raw.pdb"
    puts "Done writing frame \$i to file \$j-raw.pdb"
    set j [ expr {\$j + 1} ]
  }
  quit

EOF

$vmd -dispdev text -e extract_frames.tcl >& log/extract_frames.log

# ..........................................................................

# Convert frames from  pdb to crd 
cd frames-comp/
numframes=`ls -1 *.pdb | wc -l`
i=1
while [ $i -le $numframes ]; do
  cat $i-raw.pdb |  $mmgbsa_path/scripts/pdb2crd.prl > $i-raw.crd
  
  rm $i-raw.pdb
  ((i++))
done

# Find number of frames
echo "Number of frames : " $numframes

cd $basedir

# Put the number of frames into the definitions file
sed -i "s/XXXNFRAMES/$numframes/" data/definitions.str 

# ..........................................................................
# CHARMM RUNS

# Converting frames so that the atom order is correct
# This is necessary when using the RESI option to read parts of the system
echo "Running charmm chomp-frames.inp ... "
$charmm < $inputs/chomp-frames.inp > outputs/chomp.out
if [ $? -ne 0 ]; then
    echo "ERROR : charmm chomp-frames.inp"
    exit 1
fi

echo "Done."


