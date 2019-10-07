#!/bin/bash -l

current=$(pwd)

################################################################################################
#####                                                                                      #####
#####  First, let's define some parameters that describe how the MM-GBSA jobs were run.    #####
#####                                                                                      #####
################################################################################################
mytraj=$1
job_num=$2 		# number of subjobs
frames_per_job=$3	# number of frames per subjob

################################################################################################

source $mmgbsa_path/scripts/setenv.sh

################################################################################################
#####                                                                                      #####
#####  Next, let's get the total number of frames that were analyzed.                      #####
#####                                                                                      #####
################################################################################################

if [[ ${mytraj##*.} == "xtc" ]] ; then
	trajtypeflag="-xtc"
elif [[ ${mytraj##*.} == "dcd" ]] ; then
	trajtypeflag="-dcd"
else
	echo "ERROR : Unrecognized trajectory file type"
	exit 1
fi

frame_num=` $mmgbsa_path/parallel_scripts/catdcd -num $trajtypeflag $mytraj | awk '($1=="Total"){print $3}'  `

if [[ $((job_num*frames_per_job)) -lt $frame_num ]] ; then
	frame_num=$((job_num*frames_per_job))
fi

################################################################################################

################################################################################################
#####                                                                                      #####
#####  Next, let's create a directory structure in which to place all of the results       #####
#####  from the sub-jobs, as well as edit the definitions.str file to report the correct   #####
#####  number of frames.                                                                   #####
#####                                                                                      #####
################################################################################################
# mkdir final_results
# cd ./final_results
# mkdir data inter log outputs sas-a sas-b sas-comp solv-a solv-b solv-comp total
# cp $current/0001/data/* ./data/.

# Now we collect results in the original MMGBSA directory. 
mkdir inter sas-a sas-b sas-comp solv-a solv-b solv-comp total


sed -i "s/SET nframes XXXNFRAMES/SET nframes $frame_num/" ./data/definitions.str
################################################################################################


################################################################################################
#####                                                                                      #####
#####  In this section, we'll collect and analyze all of the interaction energy results,   #####
#####  from each of the sub-jobs.                                                          #####
#####                                                                                      #####
################################################################################################
counter=1

while [ $counter -le $job_num ]
do
        job_num_formatted=`printf %04i $counter`
        multiplier=$(((counter-1) * frames_per_job))
        if [ $counter -lt $job_num ]
        then
                end=$frames_per_job
        else
                end=$((frame_num-multiplier))
        fi
        
        for i in $(seq 1 $end)
        do
                tmp_num=$((i+multiplier))
                cp $current/$job_num_formatted/inter/inter-byres-${i}-a.dat ./inter/inter-byres-${tmp_num}-a.dat                               cp $current/$job_num_formatted/inter/inter-byres-${i}-b.dat ./inter/inter-byres-${tmp_num}-b.dat
        done
        
        counter=$((counter+1))
done
                        
unset counter i job_num_formatted multiplier end_multiplier end tmp_num
################################################################################################
# Global interaction
$parallel_scripts/concatenate_renumber_and_stats.sh total/inter-global.dat $current $job_num

# Calculate contributions
$perl_scripts/inter-contri.prl > ./log/inter-contri.log

################################################################################################


################################################################################################
#####                                                                                      #####
#####  In this section, we'll collect and analyze all of the SASA results, from each of    #####
#####  sub-jobs.                                                                           #####
#####                                                                                      #####
################################################################################################
# SASA A per res
resA=$(grep '!Ares' ./data/definitions.str | grep -Eo '[0-9]+')
resB=$(grep '!Bres' ./data/definitions.str | grep -Eo '[0-9]+')

both_A_B=$(echo $resA $resB)

for i in $resA
do
        $parallel_scripts/concatenate_renumber_and_stats.sh sas-a/sas-a-res-${i}.dat $current $job_num
done

################################################################################################
# SASA A collect average values per residue

rm -f ./sas-a/sas-a-res.tmp
for i in $resA
do        
        awk '($1=="AVG"){printf "%4d    %10.4f %10.4f %10.4f \n", ii,$2,$3,$4}' ii=$i ./sas-a/sas-a-res-${i}.dat  >> ./sas-a/sas-a-res.tmp
done

awk '{  print $0; s2=s2+$2; s3=s3+$3; s4=s4+$4}; 
        END{  print "--------------------------------------------";
        printf "%4s    %10.4f %10.4f %10.4f \n", "TOT", s2, s3, s4 }' ./sas-a/sas-a-res.tmp > ./sas-a/sas-a-res.dat
rm ./sas-a/sas-a-res.tmp  

################################################################################################
# SASA B per res

for i in $resB
do
        $parallel_scripts/concatenate_renumber_and_stats.sh sas-b/sas-b-res-${i}.dat $current $job_num
done

################################################################################################
# SASA A collect average values per residue

rm -f ./sas-b/sas-b-res.tmp
for i in $resB
do        
        awk '($1=="AVG"){printf "%4d    %10.4f %10.4f %10.4f \n", ii,$2,$3,$4}' ii=$i ./sas-b/sas-b-res-${i}.dat  >> ./sas-b/sas-b-res.tmp
done

awk '{  print $0; s2=s2+$2; s3=s3+$3; s4=s4+$4}; 
        END{  print "--------------------------------------------";
        printf "%4s    %10.4f %10.4f %10.4f \n", "TOT", s2, s3, s4 }' ./sas-b/sas-b-res.tmp > ./sas-b/sas-b-res.dat
rm ./sas-b/sas-b-res.tmp  

################################################################################################
# SASA AB per res
for i in $both_A_B
do
        $parallel_scripts/concatenate_renumber_and_stats.sh sas-comp/sas-comp-res-${i}.dat $current $job_num
done

################################################################################################
# SASA AB collect average values per residue

rm -f ./sas-comp/sas-comp-res.tmp
for i in $both_A_B
do        
        awk '($1=="AVG"){printf "%4d    %10.4f %10.4f %10.4f \n", ii,$2,$3,$4}' ii=$i ./sas-comp/sas-comp-res-${i}.dat  >> ./sas-comp/sas-comp-res.tmp
done

awk '{ print $0; s2=s2+$2; s3=s3+$3; s4=s4+$4}; 
        END{  print "--------------------------------------------";
        printf "%4s    %10.4f %10.4f %10.4f \n", "TOT", s2, s3, s4 }' ./sas-comp/sas-comp-res.tmp > ./sas-comp/sas-comp-res.dat
rm ./sas-comp/sas-comp-res.tmp  

################################################################################################
# Global SASA
counter=1
rm -f ./total/buried-sasa.tmp
while [ $counter -le $job_num ]
do
        job_num_formatted=`printf %04i $counter`
        cat $current/$job_num_formatted/total/buried-sasa.dat >> ./total/buried-sasa.tmp
        counter=$((counter+1))
done
unset counter job_num_formatted

awk '{print NR, $2,$3,$4}' ./total/buried-sasa.tmp > ./total/buried-sasa.dat
rm  ./total/buried-sasa.tmp

$parallel_scripts/concatenate_renumber_and_stats.sh total/buried-sasa.dat $current $job_num

################################################################################################


################################################################################################
#####                                                                                      #####
#####  In this section, we'll collect and analyze all of the generalized born results,     #####
#####  for each of the sub-jobs.                                                           #####
#####                                                                                      #####
################################################################################################
# GB A per frame 
counter=1

while [ $counter -le $job_num ]
do
        job_num_formatted=`printf %04i $counter`
        multiplier=$(((counter-1) * frames_per_job))
        if [ $counter -lt $job_num ]
        then
                end=$frames_per_job
        else
                end=$((frame_num-multiplier))
        fi
        
        for i in $(seq 1 $end)
        do
                tmp_num=$((i+multiplier))
                cp $current/$job_num_formatted/solv-a/solv-a-frame-${i}.dat ./solv-a/solv-a-frame-${tmp_num}.dat                      
        done
        
        counter=$((counter+1))
done

unset counter i job_num_formatted multiplier end_multiplier end tmp_num
################################################################################################
# GB A per residue

for i in $resA
do
        $parallel_scripts/concatenate_renumber_and_stats.sh solv-a/solv-a-res-${i}.dat $current $job_num
done

#################################################################################################
# GB A Collect average values per residue

rm -f ./solv-a/solv-a-res.tmp
for i in $resA
do        
        awk '($1=="AVG"){printf "%4d    %10.4f %10.4f %10.4f \n", ii,$2,$3,$4}' ii=$i ./solv-a/solv-a-res-${i}.dat  >> ./solv-a/solv-a-res.tmp
done

awk '{ print $0;  s2=s2+$2; s3=s3+$3; s4=s4+$4}; 
        END{  print "--------------------------------------------";
        printf "%4s    %10.4f %10.4f %10.4f \n", "TOT", s2, s3, s4 }' ./solv-a/solv-a-res.tmp > ./solv-a/solv-a-res.dat
rm ./solv-a/solv-a-res.tmp  


################################################################################################
# GB B per frame 
counter=1

while [ $counter -le $job_num ]
do
        job_num_formatted=`printf %04i $counter`
        multiplier=$(((counter-1) * frames_per_job))
        if [ $counter -lt $job_num ]
        then
                end=$frames_per_job
        else
                end=$((frame_num-multiplier))
        fi
        
        for i in $(seq 1 $end)
        do
                tmp_num=$((i+multiplier))
                cp $current/$job_num_formatted/solv-b/solv-b-frame-${i}.dat ./solv-b/solv-b-frame-${tmp_num}.dat                      
        done
        
        counter=$((counter+1))
done

unset counter i job_num_formatted multiplier end_multiplier end tmp_num
################################################################################################
# GB B per residue

for i in $resB
do
        $parallel_scripts/concatenate_renumber_and_stats.sh solv-b/solv-b-res-${i}.dat $current $job_num
done

#################################################################################################
# GB B Collect average values per residue

rm -f ./solv-b/solv-b-res.tmp
for i in $resB
do        
        awk '($1=="AVG"){printf "%4d    %10.4f %10.4f %10.4f \n", ii,$2,$3,$4}' ii=$i ./solv-b/solv-b-res-${i}.dat  >> ./solv-b/solv-b-res.tmp
done

awk '{ print $0; s2=s2+$2; s3=s3+$3; s4=s4+$4}; 
        END{  print "--------------------------------------------";
        printf "%4s    %10.4f %10.4f %10.4f \n", "TOT", s2, s3, s4 }' ./solv-b/solv-b-res.tmp > ./solv-b/solv-b-res.dat
rm ./solv-b/solv-b-res.tmp  



################################################################################################
# GB AB per frame 
counter=1

while [ $counter -le $job_num ]
do
        job_num_formatted=`printf %04i $counter`
        multiplier=$(((counter-1) * frames_per_job))
        if [ $counter -lt $job_num ]
        then
                end=$frames_per_job
        else
                end=$((frame_num-multiplier))
        fi
        
        for i in $(seq 1 $end)
        do
                tmp_num=$((i+multiplier))
                cp $current/$job_num_formatted/solv-comp/solv-comp-frame-${i}.dat ./solv-comp/solv-comp-frame-${tmp_num}.dat                      
        done
        
        counter=$((counter+1))
done

unset counter i job_num_formatted multiplier end_multiplier end tmp_num
################################################################################################
# GB AB per residue

for i in $both_A_B
do
        $parallel_scripts/concatenate_renumber_and_stats.sh solv-comp/solv-comp-res-${i}.dat $current $job_num
done

#################################################################################################
# GB AB Collect average values per residue

rm -f ./solv-comp/solv-comp-res.tmp
for i in $both_A_B
do        
        awk '($1=="AVG"){printf "%4d    %10.4f %10.4f %10.4f \n", ii,$2,$3,$4}' ii=$i ./solv-comp/solv-comp-res-${i}.dat  >> ./solv-comp/solv-comp-res.tmp
done

awk '{ print $0; s2=s2+$2; s3=s3+$3; s4=s4+$4}; 
        END{  print "--------------------------------------------";
        printf "%4s    %10.4f %10.4f %10.4f \n", "TOT", s2, s3, s4 }' ./solv-comp/solv-comp-res.tmp > ./solv-comp/solv-comp-res.dat
rm ./solv-comp/solv-comp-res.tmp  

################################################################################################
#####                                                                                      #####
#####  In this section, we'll collect and analyze all of the global results,               #####
#####                                                                                      #####
################################################################################################

$parallel_scripts/concatenate_renumber_and_stats.sh total/solv-a-global.dat $current $job_num
$parallel_scripts/concatenate_renumber_and_stats.sh total/solv-b-global.dat $current $job_num
$parallel_scripts/concatenate_renumber_and_stats.sh total/solv-comp-global.dat $current $job_num

################################################################################################
#####                                                                                      #####
#####  In this section, we'll calculate final results,                                     #####
#####                                                                                      #####
################################################################################################


$perl $perl_scripts/calc-bind-global.prl  > ./log/calc-bind-global.log
$perl $perl_scripts/calc-bind-byres.prl  > ./log/calc-bind-byres.log
$perl $perl_scripts/calc-bind-byres-stat.prl > ./log/calc-bind-byres-stat.log

# Put values into pdb B-factor column
$perl $scripts/put_mmgbsa_in_pdb_beta.prl data/complex.pdb  binding_sc.dat > binding_sc.pdb 
$perl $scripts/put_mmgbsa_in_pdb_beta.prl data/complex.pdb  binding_bb.dat > binding_bb.pdb 
$perl $scripts/put_mmgbsa_in_pdb_beta.prl data/complex.pdb  binding_all.dat > binding_all.pdb 


echo "Done."
exit
