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
mkdir inter sas solv total


sed -i "s/SET nframes XXXNFRAMES/SET nframes $frame_num/" ./data/definitions.str
################################################################################################


################################################################################################
#####                                                                                      #####
#####  In this section, we'll collect and analyze all of the interaction energy results,   #####
#####  from each of the sub-jobs.                                                          #####
#####                                                                                      #####
################################################################################################

# transfer and renumber the /inter/inter-byres-*.dat files
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

# This relies on the fact that cat * will take the files in the right order...
cat $current/*/total/inter-global.dat |  awk '{print NR, $2,$3,$4}' > ./total/inter-global.dat

$perl_scripts/inter-contri-multitran.prl > ./log/inter-contri-multitraj.log


################################################################################################
#####                                                                                      #####
#####  In this section, we'll collect and analyze all of the SASA results, from each of    #####
#####  sub-jobs.                                                                           #####
#####                                                                                      #####
################################################################################################
resA=$(grep '!Ares' ./data/definitions.str | grep -Eo '[0-9]+')

for i in $resA
do

        cat $current/*/sas/sas-res-${i}.dat | grep -v "---" -v "AVE" -v "SD" | awk '
             {   for(i=2;i<=NF;i++) {sum[i] += $i; sumsq[i] += ($i)^2}
                print NR, $2,$3,$4 ;
             };
             EMD{
                print "--------------------------------------------";
                printf " AVE    ";
                for(i=2;i<=NF;i++) { printf "%10.4f ",  sum[i]/NR };
                printf "\n";
                printf "  SD    ";
                for(i=2;i<=NF;i++) { printf "%10.4f ",  sqrt((sumsq[i]-sum[i]^2/NR)/NR };
                printf "\n";
             }'
             

	mkdir ./sas/res-${i}
	counter=1



	while [ $counter -le $job_num ]
	do
		job_num_formatted=`printf %04i $counter`
		cp $current/$job_num_formatted/sas/sas-res-${i}.dat ./sas/res-${i}/sas-res-${i}-${job_num_formatted}.dat
		num_lines=$(wc -l ./sas/res-${i}/sas-res-${i}-${job_num_formatted}.dat | grep -Eo '[0-9]+' | head -1)
		num_lines=$((num_lines-3))
		sed -i -n -e "1,$num_lines p" ./sas/res-${i}/sas-res-${i}-${job_num_formatted}.dat
		counter=$((counter+1))
	done
	
	cat ./sas/res-${i}/*.dat > ./sas/sas-res-${i}.dat
	rm -r ./sas/res-${i}

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

cat $current/*/total/sasa.dat |  awk '{print NR, $2,$3,$4,$5,$6}' > ./total/sasa.dat


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
	mkdir ./solv/res-${i}
	counter=1

	while [ $counter -le $job_num ]
	do
		job_num_formatted=`printf %04i $counter`
		cp $current/$job_num_formatted/solv/solv-res-${i}.dat ./solv/res-${i}/solv-res-${i}-${job_num_formatted}.dat
                num_lines=$(wc -l ./solv/res-${i}/solv-res-${i}-${job_num_formatted}.dat | grep -Eo '[0-9]+' | head -1)
                num_lines=$((num_lines-3))
                sed -i -n -e "1,$num_lines p" ./solv/res-${i}/solv-res-${i}-${job_num_formatted}.dat	
		counter=$((counter+1))
	done
	
	cat ./solv/res-${i}/*.dat > ./solv/solv-res-${i}.dat
	rm -r ./solv/res-${i}

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
m
cat $current/*/total/solv-global.dat |  awk '{print NR, $2}' > ./total/solv-global.dat

################################################################################################

$perl $perl_scripts/full-contri-multitraj.prl  > ./log/full-contri-multitraj.log
$perl $perl_scripts/full-contri-multitraj-stat.prl  > ./log/full-contri-multitraj-stat.log
$perl $perl_scripts/full-global-multitraj.prl > ./log/full-global-multitraj.log


echo "Done."
exit
