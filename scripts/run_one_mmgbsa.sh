#!/bin/bash

# -------------------------------------------------------------------------
#mmgbsa_path=/home/des2037/mmgbsa2.0/

# Environment is read from global variables. 
# main_tmp=$1
# source $main_tmp/setenv.sh

echo "Started local mmgbsa calculation ..."
echo "Host : $HOSTNAME"
pwd

# -------------------------------------------------------------------------
#inter

$charmm < $inputs/calc-inter-A.inp > outputs/calc-inter-A.out 
wait
    
$charmm < $inputs/calc-inter-B.inp > outputs/calc-inter-B.out
wait 
    
$charmm < $inputs/calc-inter-global.inp > outputs/calc-inter-global.out 
wait
echo "Finished inter charmm."

$perl_scripts/inter-contri.prl > log/inter-contri.log 
wait
echo "Finished inter perl."

# -------------------------------------------------------------------------
# sas

$charmm < $inputs/calc-sas.inp > outputs/calc-sas.out 
wait
echo "Finished sas charmm."

$perl $perl_scripts/sas-contri-a.prl > log/sas-contri-a.log
wait

$perl $perl_scripts/sas-contri-b.prl  > log/sas-contri-b.log
wait

$perl $perl_scripts/sas-contri-comp.prl  > log/sas-contri-comp.log
wait
echo "Finished sas perl."

# -------------------------------------------------------------------------
#solv

# comp
$charmm < $inputs/solv-comp.inp > outputs/solv-comp.out
wait 
echo "Finished solv-comp charmm."

$perl $perl_scripts/solv-contri-comp.prl  > log/solv-contri-comp.log 
wait
echo "Finished solv-comp perl"

# a
$charmm < $inputs/solv-a.inp > outputs/solv-a.out
wait 
echo "Finished solv-a charmm."

$perl $perl_scripts/solv-contri-a.prl  > log/solv-contri-a.log
wait 
echo "Finished solv-a perl."

# b
$charmm < $inputs/solv-b.inp > outputs/solv-b.out
wait 
echo "Finished solv-b charmm."

$perl $perl_scripts/solv-contri-b.prl  > log/solv-contri-b.log 
wait
echo "Finished solv-b perl."

$perl $perl_scripts/solv-contri-tot.prl  > log/solv-contri-tot.log
wait
echo "Finished all solv."
  
# -------------------------------------------------------------------------
# Total

$perl $perl_scripts/calc-bind-global.prl  > log/calc-bind-global.log
echo "Finished bind global."


$perl $perl_scripts/calc-bind-byres.prl  > log/calc-bind-byres.log
echo "Finished bind byres."

echo "Done."

