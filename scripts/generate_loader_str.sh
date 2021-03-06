#!/bin/bash -l

PWD=`pwd`

cd ${PWD}/top_files_mackerell/.

cat > ../charmm_inputs/loader.str <<EOL

!------ Aliases
SET lib BASEDIR/data/
! Note that BASEDIR cannot contain capital letters, due to a limitation in the way Charmm handles variables.
! Therefore it is more robust to use relative paths.

EOL

counter=1
# add all rtfs
for this_rtf in $(ls *.rtf 2> /dev/null); do
    if [ $counter == 1 ]; then
        cat >> ../charmm_inputs/loader.str << EOL
!------ Topology
open unit 1 card read name @lib/${this_rtf}
read RTF card unit 1
close unit 1

EOL
    ((counter++))
    else 
        cat >> ../charmm_inputs/loader.str << EOL
!------ Topology
open unit 1 card read name @lib/${this_rtf}
read RTF card unit 1 append
close unit 1
    
EOL
    fi
done


counter=1
# add all pars/prm
for this_par_prm in $(ls *.prm *par 2> /dev/null); do
    if [ $counter == 1 ]; then
        cat >> ../charmm_inputs/loader.str << EOL
!------ Parameters
open unit 1 card read name @lib/${this_par_prm}
read PARA card flex unit 1
close unit 1

EOL
    ((counter++))
    else 
        cat >> ../charmm_inputs/loader.str << EOL
!------ Parameters
open unit 1 card read name @lib/${this_par_prm}
read PARA card flex unit 1 append
close unit 1
    
EOL
    fi
done


cat >> ../charmm_inputs/loader.str << EOL
!------ Stream files
EOL

for this_str in $(ls *str 2> /dev/null); do
    cat >> ../charmm_inputs/loader.str << EOL
STREAM @lib/${this_str}
EOL
done

cat >> ../charmm_inputs/loader.str << EOL

!------ System
OPEN UNIT 1 READ CARD NAME @lib/complex.psf
READ PSF CARD UNIT 1
CLOSE UNIT 1

OPEN UNIT 1 READ CARD NAME @lib/complex.crd
READ COOR CARD UNIT 1
CLOSE UNIT 1

OPEN UNIT 1 READ CARD NAME @lib/definitions.crd
READ COOR COMP CARD UNIT 1
CLOSE UNIT 1
EOL

cd ${PWD}
