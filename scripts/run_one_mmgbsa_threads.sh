#!/bin/bash

# -------------------------------------------------------------------------
mmgbsa_path=/home/mac2109/mmgbsa/mmgbsa2.0/
source $mmgbsa_path/scripts/setenv.sh

# -------------------------------------------------------------------------
#inter
(
  # Start 3 sub-jobs
  (
    $charmm < $inputs/calc-inter-A.inp > outputs/calc-inter-A.out &
    $charmm < $inputs/calc-inter-B.inp > outputs/calc-inter-B.out &
    $charmm < $inputs/calc-inter-global.inp > outputs/calc-inter-global.out &
    wait
    if ((`grep -q " NORMAL TERMINATION" outputs/calc-inter-A.out`) && (`grep -q " NORMAL TERMINATION" outputs/calc-inter-B.out`) && ( `grep -q " NORMAL TERMINATION" outputs/calc-inter-B.out`) ) then
    	echo "Finished inter charmm."
    else
    	echo "ERROR in inter charmm !"	
    fi
  )
  $perl_scripts/inter-contri.prl > log/inter-contri.log 
  echo "Finished inter perl."
) &

# -------------------------------------------------------------------------
# sas
(
  # Only 1 subjob.
  $charmm < $inputs/calc-sas.inp > outputs/calc-sas.out 
  if (`grep -q " NORMAL TERMINATION" outputs/calc-sas.out`) then
    echo "Finished SAS charmm."
  else
    echo "ERROR in SAS charmm !"	
  fi
  $perl $perl_scripts/sas-contri-a.prl > log/sas-contri-a.log;
  $perl $perl_scripts/sas-contri-b.prl  > log/sas-contri-b.log;
  $perl $perl_scripts/sas-contri-comp.prl  > log/sas-contri-comp.log; 
  echo "Finished sas perl."
) &

# -------------------------------------------------------------------------
#solv
(
  # Start 3 sub-jobs with two parts each
  (
    ( 
      # comp
      $charmm < $inputs/solv-comp.inp > outputs/solv-comp.out; 
      if (`grep -q " NORMAL TERMINATION" outputs/solv-comp.out`) then
      	echo "Finished solv-comp charmm."
      else
        echo "ERROR in solv-comp charmm ! "
      fi
      $perl $perl_scripts/solv-contri-comp.prl  > log/solv-contri-comp.log 
      echo "Finished solv-comp perl"
    ) &
    ( 
      # a
      $charmm < $inputs/solv-a.inp > outputs/solv-a.out; 
      if (`grep -q " NORMAL TERMINATION" outputs/solv-a.out`) then
      	echo "Finished solv-a charmm."
      else
        echo "ERROR in solv-a charmm ! "
      fi
      $perl $perl_scripts/solv-contri-a.prl  > log/solv-contri-a.log 
      echo "Finished solv-a perl."
    ) &
    (
      # b
      $charmm < $inputs/solv-b.inp > outputs/solv-b.out; 
      if (`grep -q " NORMAL TERMINATION" outputs/solv-b.out`) then
      	echo "Finished solv-b charmm."
      else
        echo "ERROR in solv-b charmm ! "
      fi
      $perl $perl_scripts/solv-contri-b.prl  > log/solv-contri-b.log 
      echo "Finished solv-b perl."
    ) &
    wait
  )
  $perl $perl_scripts/solv-contri-tot.prl  > log/solv-contri-tot.log
  echo "Finished all solv."
)& 

wait
  
# -------------------------------------------------------------------------
# Total

# Global results for A and B :
$perl $perl_scripts/calc-bind-global.prl  > log/calc-bind-global.log

# Per-residue decomposition with components
$perl $perl_scripts/calc-bind-byres.prl  > log/calc-bind-byres.log

# Statistical analysis of per-residue binding free energies
$perl $perl_scripts/calc-bind-byres-stat.prl > log/calc-bind-byres-stat.log

# Put values into pdb B-factor column
$scripts/put_mmgbsa_in_pdb_beta.prl data/complex.pdb  binding_sc.dat > binding_sc.pdb 
$scripts/put_mmgbsa_in_pdb_beta.prl data/complex.pdb  binding_bb.dat > binding_bb.pdb 
$scripts/put_mmgbsa_in_pdb_beta.prl data/complex.pdb  binding_all.dat > binding_all.pdb 

echo "Done."

