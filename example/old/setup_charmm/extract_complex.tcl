  mol new system.namd.psf
  mol addfile system.pdb
  set sel [atomselect top "protein or (chain S T U L M N and not lipid)" ]
  $sel writepdb complex_raw.pdb
  $sel writepsf complex_raw.psf
  set nn [$sel num]
  puts "There are $nn atoms in the selection"
  quit
