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

	if [ $counter -le 1 ]
	then
		job_num_formatted=`printf %04i $counter`
		cp $current/$job_num_formatted/inter/inter-byres-[0-9]*.dat ./inter/.
	elif [ $counter -lt $job_num ]
	then
		job_num_formatted=`printf %04i $counter`
		multiplier=$(((counter-1) * frames_per_job))
		
		for i in $(seq 1 $frames_per_job)
		do
			tmp_num=$((i+multiplier))
			cp $current/$job_num_formatted/inter/inter-byres-${i}.dat ./inter/inter-byres-${tmp_num}.dat
		done
	else
		job_num_formatted=`printf %04i $counter`
		multiplier=$(((counter-1) * frames_per_job))
              
		end=$((frame_num-multiplier))

		for i in $(seq 1 $end)
                do
                        tmp_num=$((i+multiplier))
                        cp $current/$job_num_formatted/inter/inter-byres-${i}.dat ./inter/inter-byres-${tmp_num}.dat
                done	
	fi

	counter=$((counter+1))
done

unset counter i job_num_formatted multiplier end_multiplier end tmp_num

#===================================================================================
# MAC to check later :
# All this seems to amount to concatenating and renumbering the rows in the file...
# This relies on the fact that cat * will take the files in the right order...
# I prefer the version below, which involves much less file manipulation and does not rely on the cat * order.

counter=1
rm -f ./total/inter-global.dat
while [ $counter -le $job_num ]
do
	job_num_formatted=`printf %04i $counter`
	cat $current/$job_num_formatted/total/inter-global.dat >> ./total/inter-global.tmp
	counter=$((counter+1))
done
unset counter job_num_formatted 

#echo -e "inter_global <- read.csv('./total/inter-global.dat', header=FALSE)\n\
#\n\
#i <- seq(1, nrow(inter_global), by=1)\n\
#inter_global <- inter_global[,2:4]\n\
#inter_global <- cbind(i, inter_global)\n\
#write.table(inter_global, './total/inter-global.dat', row.names=FALSE, col.names=FALSE, sep=',')\n\
#q(save='no')" > ./tmp.R 
#
#Rscript tmp.R
#rm tmp.R
#
#sed -i 's/^/ /' ./total/inter-global.dat
#sed -i 's/,/  /' ./total/inter-global.dat
#sed -i 's/,/ /' ./total/inter-global.dat
#sed -i 's/,/   /' ./total/inter-global.dat

# Replace all of the above with:
awk '{print NR, $2,$3,$4}' ./total/inter-global.tmp > ./total/inter-global.dat
rm  ./total/inter-global.

# We apply these modifications everywhere below...

# We could do even simpler (if we rely also on the right cat * order):
# cat $current/*/total/inter-global.dat |  awk '{print NR, $2,$3,$4}' > ./total/inter-global.dat

# MAC end of remark =============================================================

$perl_scripts/inter-contri-multitraj.prl > ./log_collect/inter-contri-multitraj.log

################################################################################################


################################################################################################
#####                                                                                      #####
#####  In this section, we'll collect and analyze all of the SASA results, from each of    #####
#####  sub-jobs.                                                                           #####
#####                                                                                      #####
################################################################################################
resA=$(grep '!Ares' ./data/definitions.str | grep -Eo '[0-9]+')

for i in $resA
do
	counter=1

    rm -f ./sas/sas-res-${i}.dat
	while [ $counter -le $job_num ]
	do
		job_num_formatted=`printf %04i $counter`
		awk '($1~/[0-9]/)' $current/$job_num_formatted/sas/sas-res-${i}.dat >> ./sas/sas-res-${i}.dat
		counter=$((counter+1))
	done
	
	sed -i 's/[[:space:]]\{1,\}/,/g' ./sas/sas-res-${i}.dat
        sed -i 's/^,//g' ./sas/sas-res-${i}.dat

	echo -e "sas_a <- read.csv('./sas/sas-res-${i}.dat', header=FALSE)\n\
\n\
sas_a[,2]<-round(sas_a[,2],4)\n\
sas_a[,3]<-round(sas_a[,3],4)\n\
sas_a[,4]<-round(sas_a[,4],4)\n\
\n\
i <- seq(1, nrow(sas_a), by=1)\n\
sas_a <- sas_a[,2:4]\n\
sas_a <- cbind(i, sas_a)\n\
write.table(sas_a, './sas/sas-res-${i}.dat', row.names=FALSE, col.names=FALSE, sep=',')\n\
\n\
ave_1<-round(mean(sas_a[,2]),4)\n\
ave_2<-round(mean(sas_a[,3]),4)\n\
ave_3<-round(mean(sas_a[,4]),4)\n\
\n\
sd_1<-round(sd(sas_a[,2]),4)\n\
sd_2<-round(sd(sas_a[,3]),4)\n\
sd_3<-round(sd(sas_a[,4]),4)\n\
\n\
AVE<-c(\"AVE\")\n\
SD<-c(\"SD\")\n\
\n\
row_1<-c("AVE", ave_1, ave_2, ave_3)\n\
row_2<-c("SD", sd_1, sd_2, sd_3)\n\
stats<-rbind(row_1,row_2)\n\
write.table(stats, './sas/sas-res-${i}_stats.dat', row.names=FALSE, col.names=FALSE, sep=',', quote="FALSE")\n\
i	
q(save='no')" > ./tmp.R

	Rscript ./tmp.R > ./NULL
	rm ./tmp.R
	rm ./NULL

	echo -e "--------------------------------------------" > ./sas/line.txt
	
	awk -F, '{ printf "%4d    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./sas/sas-res-${i}.dat > ./sas/tmp.txt
	mv ./sas/tmp.txt ./sas/sas-res-${i}.dat

	awk -F, '{ printf "%3s    %11.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./sas/sas-res-${i}_stats.dat > ./sas/sas-res-${i}_stats2.dat
	
	cat ./sas/sas-res-${i}.dat ./sas/line.txt ./sas/sas-res-${i}_stats2.dat > ./sas/tmp.txt
	mv ./sas/tmp.txt ./sas/sas-res-${i}.dat

	sed -i 's/ SD/SD /' ./sas/sas-res-${i}.dat
	rm ./sas/sas-res-${i}_stats2.dat 
done

echo " " > ./sas/sas-res.dat

for i in $resA
do
	ave_1=$(grep 'AVE' ./sas/sas-res-${i}_stats.dat | awk -F, '{print $2}')
	ave_2=$(grep 'AVE' ./sas/sas-res-${i}_stats.dat | awk -F, '{print $3}')
	ave_3=$(grep 'AVE' ./sas/sas-res-${i}_stats.dat | awk -F, '{print $4}')
	
	echo $i","$ave_1","$ave_2","$ave_3 >> ./sas/sas-res.dat
done

rm ./sas/*_stats.dat

sed -i -e "1d" ./sas/sas-res.dat

echo -e "sas <- read.csv('./sas/sas-res.dat', header=FALSE)\n\
\n\
sas_sum<-format(round(colSums(sas[,2:4]),4), nsmall=4)\n\
sas_line <- c(\"TOT\",sas_sum)\n\
sas_line <- as.character(sas_line)\n\
sas_line <- t(sas_line)\n\
write.table(sas_line, './sas/sas-res_stat.dat', row.names=FALSE, col.names=FALSE, sep=',', quote=FALSE)\n\
q(save='no')" > ./tmp.R 

Rscript tmp.R
rm tmp.R

awk -F, '{ printf "%4d    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./sas/sas-res.dat > ./sas/tmp.txt
mv ./sas/tmp.txt ./sas/sas-res.dat

awk -F, '{ printf "%4s    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./sas/sas-res_stat.dat > ./sas/tmp.txt
mv ./sas/tmp.txt ./sas/sas-res_stat.dat

cat ./sas/sas-res.dat ./sas/line.txt ./sas/sas-res_stat.dat > ./sas/tmp.txt
mv ./sas/tmp.txt ./sas/sas-res.dat
sed -i 's/ TOT/TOT /' ./sas/sas-res.dat

rm ./sas/line.txt ./sas/sas-res_stat.dat

################################################################################################

################################################################################################

counter=1
rm -f ./total/sasa.dat
while [ $counter -le $job_num ]
do
        job_num_formatted=`printf %04i $counter`
        cat $current/$job_num_formatted/total/sasa.dat >> ./total/sasa.dat
        counter=$((counter+1))
done
unset counter job_num_formatted

awk '{print NR, $2,$3,$4}' ./total/sasa.tmp > ./total/sasa.dat
rm  ./total/sasa.tmp


################################################################################################


################################################################################################
#####                                                                                      #####
#####  In this section, we'll collect and analyze all of the generalized born results,     #####
#####  for each of the sub-jobs.                                                           #####
#####                                                                                      #####
################################################################################################
counter=1

while [ $counter -le $job_num ]
do

        if [ $counter -le 1 ]
        then 
                job_num_formatted=`printf %04i $counter`
                cp $current/$job_num_formatted/solv/solv-frame-*.dat ./solv/.
        elif [ $counter -lt $job_num ]
        then 
                job_num_formatted=`printf %04i $counter`
                multiplier=$(((counter-1) * frames_per_job))
                
                for i in $(seq 1 $frames_per_job)
                do
                        tmp_num=$((i+multiplier))
                        cp $current/$job_num_formatted/solv/solv-frame-${i}.dat ./solv/solv-frame-${tmp_num}.dat                      
                done
        else    
                job_num_formatted=`printf %04i $counter`
                multiplier=$(((counter-1) * frames_per_job))
                
                end=$((frame_num-multiplier))

                for i in $(seq 1 $end)
                do
                        tmp_num=$((i+multiplier))
                        cp $current/$job_num_formatted/solv/solv-frame-${i}.dat ./solv/solv-frame-${tmp_num}.dat
                done
        fi

        counter=$((counter+1))
done

unset counter i job_num_formatted multiplier end_multiplier end tmp_num
################################################################################################
for i in $resA
do
	counter=1
	rm -f ./solv/solv-res-${i}.dat
	while [ $counter -le $job_num ]
	do
		job_num_formatted=`printf %04i $counter`
    	awk '($1~/[0-9]/)' $current/$job_num_formatted/solv/solv-res-${i}.dat >>./solv/solv-res-${i}.dat
		counter=$((counter+1))
	done

	sed -i 's/[[:space:]]\{1,\}/,/g' ./solv/solv-res-${i}.dat
        sed -i 's/^,//g' ./solv/solv-res-${i}.dat

	echo -e "solv_a <- read.csv('./solv/solv-res-${i}.dat', header=FALSE)\n\
\n\
solv_a[,2]<-round(solv_a[,2],4)\n\
solv_a[,3]<-round(solv_a[,3],4)\n\
solv_a[,4]<-round(solv_a[,4],4)\n\
\n\
i <- seq(1, nrow(solv_a), by=1)\n\
solv_a <- solv_a[,2:4]\n\
solv_a <- cbind(i, solv_a)\n\
write.table(solv_a, './solv/solv-res-${i}.dat', row.names=FALSE, col.names=FALSE, sep=',')\n\
\n\
ave_1<-round(mean(solv_a[,2]),4)\n\
ave_2<-round(mean(solv_a[,3]),4)\n\
ave_3<-round(mean(solv_a[,4]),4)\n\
\n\
sd_1<-round(sd(solv_a[,2]),4)\n\
sd_2<-round(sd(solv_a[,3]),4)\n\
sd_3<-round(sd(solv_a[,4]),4)\n\
\n\
AVE<-c(\"AVE\")\n\
SD<-c(\"SD\")\n\
\n\
row_1<-c("AVE", ave_1, ave_2, ave_3)\n\
row_2<-c("SD", sd_1, sd_2, sd_3)\n\
stats<-rbind(row_1,row_2)\n\
write.table(stats, './solv/solv-res-${i}_stats.dat', row.names=FALSE, col.names=FALSE, sep=',', quote="FALSE")\n\
i	
q(save='no')" > ./tmp.R

	Rscript ./tmp.R > ./NULL
	rm ./tmp.R
	rm ./NULL

	echo -e "--------------------------------------------" > ./solv/line.txt
	
	awk -F, '{ printf "%4d    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./solv/solv-res-${i}.dat > ./solv/tmp.txt
	mv ./solv/tmp.txt ./solv/solv-res-${i}.dat

	awk -F, '{ printf "%3s    %11.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./solv/solv-res-${i}_stats.dat > ./solv/solv-res-${i}_stats2.dat
	
	cat ./solv/solv-res-${i}.dat ./solv/line.txt ./solv/solv-res-${i}_stats2.dat > ./solv/tmp.txt
	mv ./solv/tmp.txt ./solv/solv-res-${i}.dat

	sed -i 's/ SD/SD /' ./solv/solv-res-${i}.dat
	rm ./solv/solv-res-${i}_stats2.dat 
done

echo " " > ./solv/solv-res.dat

for i in $resA
do
	ave_1=$(grep 'AVE' ./solv/solv-res-${i}_stats.dat | awk -F, '{print $2}')
	ave_2=$(grep 'AVE' ./solv/solv-res-${i}_stats.dat | awk -F, '{print $3}')
	ave_3=$(grep 'AVE' ./solv/solv-res-${i}_stats.dat | awk -F, '{print $4}')
	
	echo $i","$ave_1","$ave_2","$ave_3 >> ./solv/solv-res.dat
done

rm ./solv/*_stats.dat

sed -i -e "1d" ./solv/solv-res.dat

echo -e "sas <- read.csv('./solv/solv-res.dat', header=FALSE)\n\
\n\
sas_sum<-format(round(colSums(sas[,2:4]),4), nsmall=4)\n\
sas_line <- c(\"TOT\",sas_sum)\n\
sas_line <- as.character(sas_line)\n\
sas_line <- t(sas_line)\n\
write.table(sas_line, './solv/solv-res_stat.dat', row.names=FALSE, col.names=FALSE, sep=',', quote=FALSE)\n\
q(save='no')" > ./tmp.R 

Rscript tmp.R
rm tmp.R

awk -F, '{ printf "%4d    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./solv/solv-res.dat > ./solv/tmp.txt
mv ./solv/tmp.txt ./solv/solv-res.dat

awk -F, '{ printf "%4s    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./solv/solv-res_stat.dat > ./solv/tmp.txt
mv ./solv/tmp.txt ./solv/solv-res_stat.dat

cat ./solv/solv-res.dat ./solv/line.txt ./solv/solv-res_stat.dat > ./solv/tmp.txt
mv ./solv/tmp.txt ./solv/solv-res.dat
sed -i 's/ TOT/TOT /' ./solv/solv-res.dat

rm ./solv/line.txt ./solv/solv-res_stat.dat
################################################################################################

counter=1
rm -f ./total/solv-global.dat
while [ $counter -le $job_num ]
do
        job_num_formatted=`printf %04i $counter`
        cat $current/$job_num_formatted/total/solv-global.dat >> ./total/solv-global.dat
        counter=$((counter+1))
done
unset counter job_num_formatted

awk '{print NR, $2,$3,$4}' ./total/solv-global.tmp > ./total/solv-global.dat
rm  ./total/solv-global.


################################################################################################

$perl $perl_scripts/full-contri-multitraj.prl  > ./log_collect/full-contri-multitraj.log
$perl $perl_scripts/full-contri-multitraj-stat.prl  > ./log_collect/full-contri-multitraj-stat.log
$perl $perl_scripts/full-global-multitraj.prl > ./log_collect/full-global-multitraj.log


echo "Done."
exit
