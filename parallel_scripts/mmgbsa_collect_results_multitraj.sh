#!/bin/bash -l

current=$(pwd)

# source ./setenv.sh

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
# mkdir data inter log outputs sas sas-b sas-comp solv-a solv-b solv-comp total
# cp $current/0001/data/* ./data/.

# Now we collect results in the original MMGBSA directory. 
mkdir inter sas solv total log_collect


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
                cp $current/$job_num_formatted/inter/inter-byres-${i}.dat ./inter/inter-byres-${tmp_num}.dat                      
        done
        
        counter=$((counter+1))
done

unset counter i job_num_formatted multiplier end tmp_num

################################################################################################

counter=1
rm -f ./total/inter-global.dat
while [ $counter -le $job_num ]
do
	job_num_formatted=`printf %04i $counter`
	cat $current/$job_num_formatted/total/inter-global.dat >> ./total/inter-global.tmp
	counter=$((counter+1))
done
unset counter job_num_formatted 

$perl_scripts/renumber_and_stats.prl ./total/inter-global.tmp > ./total/inter-global.dat
rm  ./total/inter-global.tmp

# We could do even simpler (if we rely also on the right cat * order):
# cat $current/*/total/inter-global.dat |  awk '{print NR, $2,$3,$4}' > ./total/inter-global.dat

$perl_scripts/inter-contri-multitraj.prl > ./log_collect/inter-contri-multitraj.log

################################################################################################


################################################################################################
#####                                                                                      #####
#####  In this section, we'll collect and analyze all of the SASA results, from each of    #####
#####  sub-jobs.                                                                           #####
#####                                                                                      #####
################################################################################################
# SASA per res
resA=$(grep '!Ares' ./data/definitions.str | grep -Eo '[0-9]+')

for i in $resA
do
	counter=1
        rm -f ./sas/sas-res-${i}.tmp
        
	while [ $counter -le $job_num ]
	do
		job_num_formatted=`printf %04i $counter`
		awk '($1~/[0-9]/)' $current/$job_num_formatted/sas/sas-res-${i}.dat >> ./sas/sas-res-${i}.tmp
		counter=$((counter+1))
	done
	
	sed -i 's/[[:space:]]\{1,\}/,/g' ./sas/sas-res-${i}.tmp
        sed -i 's/^,//g' ./sas/sas-res-${i}.tmp
        
        $perl_scripts/renumber_and_stats.prl ./sas/sas-res-${i}.tmp > ./sas/sas-res-${i}.dat
        
        rm ./sas/sas-res-${i}.tmp
done

################################################################################################
# SASA Collect average values per residue

rm -f ./sas/sas-res.tmp
for i in $resA
do        
        awk '($1=="AVE"){printf "%4d    %10.4f %10.4f %10.4f \n", ii,$2,$3,$4}' ii=$i ./sas/sas-res-${i}.dat  >> ./sas/sas-res.tmp
done

awk '{  s2=s2+$2; s3=s3+$3; s4=s4+$4}; 
        END{  print "--------------------------------------------";
        printf "%4s    %10.4f %10.4f %10.4f \n", "TOT", s2, s3, s4 }' ./sas/sas-res.tmp > ./sas/sas-res.dat
rm ./sas/sas-res.tmp  
        

################################################################################################

################################################################################################
# SASA total 
counter=1
rm -f ./total/sasa.tmp
while [ $counter -le $job_num ]
do
        job_num_formatted=`printf %04i $counter`
        cat $current/$job_num_formatted/total/sasa.dat >> ./total/sasa.tmp
        counter=$((counter+1))
done
unset counter job_num_formatted

$perl_scripts/renumber_and_stats.prl ./total/sasa.tmp > ./total/sasa.dat
rm  ./total/sasa.tmp


################################################################################################


################################################################################################
#####                                                                                      #####
#####  In this section, we'll collect and analyze all of the generalized born results,     #####
#####  for each of the sub-jobs.                                                           #####
#####                                                                                      #####
################################################################################################
# GB per frame
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
                cp $current/$job_num_formatted/solv/solv-frame-${i}.dat ./solv/solv-frame-${tmp_num}.dat                      
        done
        
        counter=$((counter+1))
done

unset counter i job_num_formatted multiplier end tmp_num

################################################################################################
# GB per residue

for i in $resA
do
	counter=1
	rm -f ./solv/solv-res-${i}.tmp
	while [ $counter -le $job_num ]
	do
		job_num_formatted=`printf %04i $counter`
    	awk '($1~/[0-9]/)' $current/$job_num_formatted/solv/solv-res-${i}.dat >>./solv/solv-res-${i}.tmp
		counter=$((counter+1))
	done

	sed -i 's/[[:space:]]\{1,\}/,/g' ./solv/solv-res-${i}.tmp
        sed -i 's/^,//g' ./solv/solv-res-${i}.tmp

	
        $perl_scripts/renumber_and_stats.prl ./solv/solv-res-${i}.tmp > ./solv/solv-res-${i}.dat
        
        rm ./solv/solv-res-${i}.tmp
done

#################################################################################################
# GB Collect average values per residue
rm -f ./solv/solv-res.tmp
for i in $resA
do        
        awk '($1=="AVE"){printf "%4d    %10.4f %10.4f %10.4f \n", ii,$2,$3,$4}' ii=$i ./solv/solv-res-${i}.dat  >> ./solv/solv-res.tmp
done

awk '{  s2=s2+$2; s3=s3+$3; s4=s4+$4}; 
        END{  print "--------------------------------------------";
        printf "%4s    %10.4f %10.4f %10.4f \n", "TOT", s2, s3, s4 }' ./solv/solv-res.tmp > ./solv/solv-res.dat
rm ./solv/solv-res.tmp  

################################################################################################
# GB total
counter=1
rm -f ./total/solv-global.tmp
while [ $counter -le $job_num ]
do
        job_num_formatted=`printf %04i $counter`
        cat $current/$job_num_formatted/total/solv-global.dat >> ./total/solv-global.tmp
        counter=$((counter+1))
done
unset counter job_num_formatted

$perl_scripts/renumber_and_stats.prl  ./total/solv-global.tmp > ./total/solv-global.dat
rm  ./total/solv-global.tmp



################################################################################################
#####                                                                                      #####
#####  In this section, we'll calculate contributions                                      #####
#####                                                                                      #####
################################################################################################

$perl $perl_scripts/full-contri-multitraj.prl  > ./log_collect/full-contri-multitraj.log
$perl $perl_scripts/full-contri-multitraj-stat.prl  > ./log_collect/full-contri-multitraj-stat.log
$perl $perl_scripts/full-global-multitraj.prl > ./log_collect/full-global-multitraj.log


echo "Done."
exit
