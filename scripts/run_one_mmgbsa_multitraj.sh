#!/bin/bash

# -------------------------------------------------------------------------
# Setting up the environment

# Environment is read from global variables. 

echo "Started local mmgbsa calculation ..."
echo "Host : $HOSTNAME"
pwd

# -------------------------------------------------------------------------
#inter

$charmm < $inputs/calc-inter-multitraj.inp > outputs/calc-inter-multitraj.out 
wait

$charmm < $inputs/calc-inter-global-multitraj.inp > outputs/calc-inter-global-multitraj.out 
wait
echo "Finished inter charmm."

$perl_scripts/inter-contri-multitraj.prl > log/inter-contri-multitraj.log 
wait
echo "Finished inter perl."

# -------------------------------------------------------------------------
# sas

$charmm < $inputs/calc-sas-multitraj.inp > outputs/calc-sas-multitraj.out 
wait
echo "Finished sas charmm."

$perl $perl_scripts/sas-contri-multitraj.prl > log/sas-multitraj.log
wait
echo "Finished sas perl."

# -------------------------------------------------------------------------
#solv

# comp
$charmm < $inputs/solv-multitraj.inp > outputs/solv-multitraj.out
wait 
echo "Finished solv charmm."

$perl $perl_scripts/solv-contri-multitraj.prl  > log/solv-contri-multitraj.log 
wait
echo "Finished solv perl"

  
# -------------------------------------------------------------------------
# Total

$perl $perl_scripts/full-contri-multitraj.prl   > log/full-contri-multitraj.log
echo "Finished full energy byres."


$perl $perl_scripts/full-global-multitraj.prl  > log/full-global-multitraj.log
echo "Finished full energy global."

echo "Done."

