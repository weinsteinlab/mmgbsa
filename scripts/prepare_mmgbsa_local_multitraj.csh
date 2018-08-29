#! /bin/tcsh -ef
# Should be run in directory $system/$mmgbsa_name/
# ./prepare_mmgbsa_local.csh traj_dir startframe endframe stride
# ARGUMENT : 
# traj_dir: path to the trajectory.
# startframe : first frame
# endframe : last frame
# stride : frame stride

# relative path to the directory with trajectory.
#set traj_dir=$1
# File name for trajectories
set trajname = $1

# time interval between frames :
set startframe = $2
set endframe = $3
set stride = $4

# Paths
set dcd_tmp = $5

set scratch_path="$dcd_tmp/$USER/mmgbsa/"
echo "Scratch path will be : $scratch_path"

# paths ( now read from environment variables )
#set scratch_path="/scratch/mac2109/mmgbsa/"
#set scratch_path="/tmp/$USER/mmgbsa/"
#set top_path="/home/mac2109/top_files/mackerell/"
#set mmgbsa_path="/home/mac2109/mmgbsa/mmgbsa2.0/"
#set inputs=$mmgbsa_path/charmm_inputs/

# Executatbles ( now read from environment variables )
#set charmm = /softlib/exe/x86_64/pkg/charmm/36a2/intel9_64_mpich-1.2.7p1/bin/charmm
#set charmm=/home/mac2109/local/charmm36a2_intel9_64_mpich-1.2.7p1/bin/charmm
#set vmd = /home/mac2109/local/vmd-1.9.2/bin/vmd 

pwd

# Prepare directory where to run the analysis.
set basedir=`pwd`
set basename=`pwd | sed 's/\//+/g' `
set basedir_backslash=`pwd | awk '{gsub("/","\\/"); print $0}'`
#set basedir_backslash=`pwd | awk '{gsub("\/","\\\/"); print $0}'` # This generates warnings on some machines.
set rundir=$scratch_path/$basename	
echo $rundir > rundir

mkdir -p outputs total inter log solv sas

if ( ! -e data/loader.str ) then
        echo "ERROR : We need a ./data directory with a loader.str file"
	exit 1
endif

if ( ! -e data/definitions.str ) then
        echo "ERROR : We need a ./data directory with a definitions.str file"
	exit 1
endif


# .......................................................................
# PREPARE DIRECTORIES

# Prepare frames directly on /scratch
set basedir=`pwd`
echo $basedir > basedir
# Specific basename for cases where the scratch directory is common. 
set basename=`pwd | sed 's/\//+/g' `

set framesdir=$scratch_path$basename'_frames-comp'	
echo $framesdir > framesdir
rm -rf  $framesdir  frames-comp      
mkdir -p $framesdir
ln -s $framesdir frames-comp
echo framesdir : $framesdir

# ..........................................................................
# FRAME EXTRACTION
#
echo " Extracting frames ..."
set mypsf="./data/system.pdb"

cat > extract_frames.tcl  << EOF
  source ./vmd_selections.tcl
  mol new $mypsf
  mol addfile $trajname waitfor all

  set nf [molinfo top get numframes]
  set sel [atomselect top "\$complex_sel_text"]

  if {$endframe > \$nf} {
     error "End frame specified is beyond trajectory end !!"
  }

  set j 1
  for {set i $startframe} {\$i <= $endframe} {incr i $stride} {
    set frameidx [ expr {\$i -1 }]
    \$sel frame \$frameidx
    \$sel writepdb "frames-comp/\$j-alpha.pdb"
    puts "Done writing frame \$i to file \$j-raw.pdb"
    set j [ expr {\$j + 1} ]
  }
  quit

EOF

$vmd -dispdev text -e extract_frames.tcl >& log/extract_frames.log

# ..........................................................................

# Convert frames from  pdb to crd 
cd frames-comp/
set numframes=`ls -1 *.pdb | wc -l`
set i=1
while ( $i <= $numframes )
  cat $i-alpha.pdb |  $mmgbsa_path/scripts/pdb2crd.prl > $i-raw.crd
  rm $i-alpha.pdb
  @ i++
end

# Find number of frames
echo "Number of fwrames : " $numframes

cd $basedir

# Put the number of frames into the definitions file
sed -i "s/XXXNFRAMES/$numframes/" data/definitions.str 

# ..........................................................................
# CHARMM RUNS

# Charmm executable
# ln -fs $charmm charmm

# Converting frames so that the atom order is correct
# This is necessary when using the RESI option to read parts of the system
echo "Running charmm chomp-frames.inp ... "
$charmm < $inputs/chomp-frames.inp > outputs/chomp.out
if ($? != 0) then
    echo "ERROR : charmm chomp-frames.inp"
    exit 1
endif

echo "Done."


