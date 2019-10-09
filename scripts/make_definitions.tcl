
# To be run in the ./system/setup_charmm/ directory

# Load the selection texts provided by the user. 
source ./vmd_selections.tcl

# ---------------------------------------------------------------
# Load  complex

# Try to do without the namd psf 
#mol new ../setup_charmm/complex_raw.psf
#mol addfile ../setup_charmm/complex_raw.pdb type pdb
mol new ./data/complex_raw.pdb 

# We have to load the original NAMD complex.pdb file 
# because after setup-charmm the chain information disappears
# This means that the atom order for CTER will be messed up in the crd file, 
# but charmm will read atoms correctly anyway.

puts "\n Selection for Part A : $A_sel_text "
puts "\n Selection for Part B : $B_sel_text "
puts "\n Selection for decomposition in A : $Aresidues_sel_text "
puts "\n Selection for decomposition in B : $Bresidues_sel_text \n"


set sel [atomselect top "all"]

set selA  [atomselect top "$A_sel_text" ]
set selB  [atomselect top "$B_sel_text" ]
set selAres  [atomselect top "$Aresidues_sel_text" ]
set selBres  [atomselect top "$Bresidues_sel_text" ]

set natom [$sel num]
set natomA [$selA num]
set natomB [$selB num]
set natomAres [$selAres num]
set natomBres [$selBres num]    

# ---------------------------------------------------------------
# Flagging and writing PDB

$sel set beta 0
# Part A of the complex
$selA set beta 1
# Part B of the complex
$selB set beta -1
# Residues in part A that will be calculated.
$selAres set beta 2
# Residues in part B that will be calculated.
$selBres set beta -2

$sel writepdb "data/definitions.pdb"


# ---------------------------------------------------------------
#  Writing the residue numbers to file 

set allA [lsort -integer -unique [$selA get residue]]
set allB [lsort -integer -unique [$selB get residue]]
set chosenA [lsort -integer -unique [$selAres get residue]]
set chosenB [lsort -integer -unique [$selBres get residue]]

# !!!! In VMD residue starts at 0, even if the numbering starts at 1 in the pdb  file ... 
# but in CHARRM IRES starts at 1 !!!!! 
# ... and in TCL, lists start at 0, as well as in perl. 
foreach temp $allA {
  lappend resA [expr $temp + 1 ];
}
foreach temp $allB {
  lappend resB [expr $temp + 1 ];
}
foreach temp $chosenA {
  lappend resAchosen [expr  $temp + 1  ];
}
foreach temp $chosenB {
  lappend resBchosen [expr $temp + 1 ];
}


set min_resA [lindex $resA 0]
set min_resB [lindex $resB 0]
set max_resA [lindex $resA end]
set max_resB [lindex $resB end]


set fp [ open "data/definitions.str" w ] 

puts $fp "\nDEFINE A SELE PROPERTY WCOMP .GT. 0.5 END\n"
puts $fp "\nDEFINE B SELE PROPERTY WCOMP .LT. -0.5 END\n"


puts $fp "SET firstresa     $min_resA"
puts $fp "SET lastresa      $max_resA"
puts $fp "SET firstresb     $min_resB"
puts $fp "SET lastresb      $max_resB\n"

puts $fp "SET nframes XXXNFRAMES\n"

# Do membrane calculation?
puts $fp "SET do_membrane     $do_membrane"

#This will be read by perl, but refer to IRES, so we take the list starting at 1
# The numbering should correspond to column 2 of crd files. 
puts $fp "!A $resA\n"
puts $fp "!B $resB\n"
puts $fp "!Ares $resAchosen\n"
puts $fp "!Bres $resBchosen\n"

close $fp 


# ---------------------------------------------------------------
# Reporting 

set n_resA [llength $allA ]
set n_resB [llength $allB ]
set n_chosenA [llength $chosenA ]
set n_chosenB [llength $chosenB ]

puts "\n Part A : $n_resA residues, $natomA atoms "
puts "\n Part B : $n_resB residues. $natomB atoms "
puts "\n Selected for decomposition in A : $n_chosenA residues, $natomAres atoms "
puts "\n Selected for decomposition in B : $n_chosenB residues, $natomBres atoms \n"


quit
