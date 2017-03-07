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

	if [ $counter -le 1 ]
	then
		job_num_formatted=`printf %04i $counter`
		cp $current/$job_num_formatted/inter/inter-byres-[0-9]*-[a-b].dat ./inter/.
	elif [ $counter -lt $job_num ]
	then
		job_num_formatted=`printf %04i $counter`
		multiplier=$(((counter-1) * frames_per_job))
		
		for i in $(seq 1 $frames_per_job)
		do
			tmp_num=$((i+multiplier))
			cp $current/$job_num_formatted/inter/inter-byres-${i}-a.dat ./inter/inter-byres-${tmp_num}-a.dat
			cp $current/$job_num_formatted/inter/inter-byres-${i}-b.dat ./inter/inter-byres-${tmp_num}-b.dat
		done
	else
		job_num_formatted=`printf %04i $counter`
		multiplier=$(((counter-1) * frames_per_job))
              
		end=$((frame_num-multiplier))

		for i in $(seq 1 $end)
                do
                        tmp_num=$((i+multiplier))
                        cp $current/$job_num_formatted/inter/inter-byres-${i}-a.dat ./inter/inter-byres-${tmp_num}-a.dat
                        cp $current/$job_num_formatted/inter/inter-byres-${i}-b.dat ./inter/inter-byres-${tmp_num}-b.dat
                done	
	fi

	counter=$((counter+1))
done

unset counter i job_num_formatted multiplier end_multiplier end tmp_num

mkdir tmp 

counter=1

while [ $counter -le $job_num ]
do
	job_num_formatted=`printf %04i $counter`
	cp $current/$job_num_formatted/total/inter-global.dat ./tmp/inter-global-${job_num_formatted}.dat
	sed -i 's/[[:space:]]\{1,\}/,/g' ./tmp/inter-global-${job_num_formatted}.dat
	sed -i 's/^,//g' ./tmp/inter-global-${job_num_formatted}.dat
	counter=$((counter+1))
done

unset counter job_num_formatted 

cat $current/tmp/* > ./total/inter-global.dat

echo -e "inter_global <- read.csv('./total/inter-global.dat', header=FALSE)\n\
\n\
i <- seq(1, nrow(inter_global), by=1)\n\
inter_global <- inter_global[,2:4]\n\
inter_global <- cbind(i, inter_global)\n\
write.table(inter_global, './total/inter-global.dat', row.names=FALSE, col.names=FALSE, sep=',')\n\
q(save='no')" > ./tmp.R 

Rscript tmp.R
rm tmp.R

sed -i 's/^/ /' ./total/inter-global.dat
sed -i 's/,/  /' ./total/inter-global.dat
sed -i 's/,/ /' ./total/inter-global.dat
sed -i 's/,/   /' ./total/inter-global.dat

rm -r ./tmp

$perl_scripts/inter-contri.prl > ./log/inter-contri.log
################################################################################################


################################################################################################
#####                                                                                      #####
#####  In this section, we'll collect and analyze all of the SASA results, from each of    #####
#####  sub-jobs.                                                                           #####
#####                                                                                      #####
################################################################################################
resA=$(grep '!Ares' ./data/definitions.str | grep -Eo '[0-9]+')
resB=$(grep '!Bres' ./data/definitions.str | grep -Eo '[0-9]+')

both_A_B=$(echo $resA $resB)

for i in $resA
do
	mkdir ./sas-a/res-${i}
	counter=1

	while [ $counter -le $job_num ]
	do
		job_num_formatted=`printf %04i $counter`
		cp $current/$job_num_formatted/sas-a/sas-a-res-${i}.dat ./sas-a/res-${i}/sas-a-res-${i}-${job_num_formatted}.dat
		num_lines=$(wc -l ./sas-a/res-${i}/sas-a-res-${i}-${job_num_formatted}.dat | grep -Eo '[0-9]+' | head -1)
		num_lines=$((num_lines-3))
		sed -i -n -e "1,$num_lines p" ./sas-a/res-${i}/sas-a-res-${i}-${job_num_formatted}.dat
		counter=$((counter+1))
	done
	
	cat ./sas-a/res-${i}/*.dat > ./sas-a/sas-a-res-${i}.dat
	rm -r ./sas-a/res-${i}

	sed -i 's/[[:space:]]\{1,\}/,/g' ./sas-a/sas-a-res-${i}.dat
        sed -i 's/^,//g' ./sas-a/sas-a-res-${i}.dat

	echo -e "sas_a <- read.csv('./sas-a/sas-a-res-${i}.dat', header=FALSE)\n\
\n\
sas_a[,2]<-round(sas_a[,2],4)\n\
sas_a[,3]<-round(sas_a[,3],4)\n\
sas_a[,4]<-round(sas_a[,4],4)\n\
\n\
i <- seq(1, nrow(sas_a), by=1)\n\
sas_a <- sas_a[,2:4]\n\
sas_a <- cbind(i, sas_a)\n\
write.table(sas_a, './sas-a/sas-a-res-${i}.dat', row.names=FALSE, col.names=FALSE, sep=',')\n\
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
write.table(stats, './sas-a/sas-a-res-${i}_stats.dat', row.names=FALSE, col.names=FALSE, sep=',', quote="FALSE")\n\
i	
q(save='no')" > ./tmp.R

	Rscript ./tmp.R > ./NULL
	rm ./tmp.R
	rm ./NULL

	echo -e "--------------------------------------------" > ./sas-a/line.txt
	
	awk -F, '{ printf "%4d    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./sas-a/sas-a-res-${i}.dat > ./sas-a/tmp.txt
	mv ./sas-a/tmp.txt ./sas-a/sas-a-res-${i}.dat

	awk -F, '{ printf "%3s    %11.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./sas-a/sas-a-res-${i}_stats.dat > ./sas-a/sas-a-res-${i}_stats2.dat
	
	cat ./sas-a/sas-a-res-${i}.dat ./sas-a/line.txt ./sas-a/sas-a-res-${i}_stats2.dat > ./sas-a/tmp.txt
	mv ./sas-a/tmp.txt ./sas-a/sas-a-res-${i}.dat

	sed -i 's/ SD/SD /' ./sas-a/sas-a-res-${i}.dat
	rm ./sas-a/sas-a-res-${i}_stats2.dat 
done

echo " " > ./sas-a/sas-a-res.dat

for i in $resA
do
	ave_1=$(grep 'AVE' ./sas-a/sas-a-res-${i}_stats.dat | awk -F, '{print $2}')
	ave_2=$(grep 'AVE' ./sas-a/sas-a-res-${i}_stats.dat | awk -F, '{print $3}')
	ave_3=$(grep 'AVE' ./sas-a/sas-a-res-${i}_stats.dat | awk -F, '{print $4}')
	
	echo $i","$ave_1","$ave_2","$ave_3 >> ./sas-a/sas-a-res.dat
done

rm ./sas-a/*_stats.dat

sed -i -e "1d" ./sas-a/sas-a-res.dat

echo -e "sas <- read.csv('./sas-a/sas-a-res.dat', header=FALSE)\n\
\n\
sas_sum<-format(round(colSums(sas[,2:4]),4), nsmall=4)\n\
sas_line <- c(\"TOT\",sas_sum)\n\
sas_line <- as.character(sas_line)\n\
sas_line <- t(sas_line)\n\
write.table(sas_line, './sas-a/sas-a-res_stat.dat', row.names=FALSE, col.names=FALSE, sep=',', quote=FALSE)\n\
q(save='no')" > ./tmp.R 

Rscript tmp.R
rm tmp.R

awk -F, '{ printf "%4d    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./sas-a/sas-a-res.dat > ./sas-a/tmp.txt
mv ./sas-a/tmp.txt ./sas-a/sas-a-res.dat

awk -F, '{ printf "%4s    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./sas-a/sas-a-res_stat.dat > ./sas-a/tmp.txt
mv ./sas-a/tmp.txt ./sas-a/sas-a-res_stat.dat

cat ./sas-a/sas-a-res.dat ./sas-a/line.txt ./sas-a/sas-a-res_stat.dat > ./sas-a/tmp.txt
mv ./sas-a/tmp.txt ./sas-a/sas-a-res.dat
sed -i 's/ TOT/TOT /' ./sas-a/sas-a-res.dat

rm ./sas-a/line.txt ./sas-a/sas-a-res_stat.dat
################################################################################################
for i in $resB
do
	mkdir ./sas-b/res-${i}
	counter=1

	while [ $counter -le $job_num ]
	do
		job_num_formatted=`printf %04i $counter`
		cp $current/$job_num_formatted/sas-b/sas-b-res-${i}.dat ./sas-b/res-${i}/sas-b-res-${i}-${job_num_formatted}.dat
                num_lines=$(wc -l ./sas-b/res-${i}/sas-b-res-${i}-${job_num_formatted}.dat | grep -Eo '[0-9]+' | head -1)
                num_lines=$((num_lines-3))
                sed -i -n -e "1,$num_lines p" ./sas-b/res-${i}/sas-b-res-${i}-${job_num_formatted}.dat
		counter=$((counter+1))
	done
	
	cat ./sas-b/res-${i}/*.dat > ./sas-b/sas-b-res-${i}.dat
	rm -r ./sas-b/res-${i}

	sed -i 's/[[:space:]]\{1,\}/,/g' ./sas-b/sas-b-res-${i}.dat
        sed -i 's/^,//g' ./sas-b/sas-b-res-${i}.dat

	echo -e "sas_b <- read.csv('./sas-b/sas-b-res-${i}.dat', header=FALSE)\n\
\n\
sas_b[,2]<-round(sas_b[,2],4)\n\
sas_b[,3]<-round(sas_b[,3],4)\n\
sas_b[,4]<-round(sas_b[,4],4)\n\
\n\
i <- seq(1, nrow(sas_b), by=1)\n\
sas_b <- sas_b[,2:4]\n\
sas_b <- cbind(i, sas_b)\n\
write.table(sas_b, './sas-b/sas-b-res-${i}.dat', row.names=FALSE, col.names=FALSE, sep=',')\n\
\n\
ave_1<-round(mean(sas_b[,2]),4)\n\
ave_2<-round(mean(sas_b[,3]),4)\n\
ave_3<-round(mean(sas_b[,4]),4)\n\
\n\
sd_1<-round(sd(sas_b[,2]),4)\n\
sd_2<-round(sd(sas_b[,3]),4)\n\
sd_3<-round(sd(sas_b[,4]),4)\n\
\n\
AVE<-c(\"AVE\")\n\
SD<-c(\"SD\")\n\
\n\
row_1<-c("AVE", ave_1, ave_2, ave_3)\n\
row_2<-c("SD", sd_1, sd_2, sd_3)\n\
stats<-rbind(row_1,row_2)\n\
write.table(stats, './sas-b/sas-b-res-${i}_stats.dat', row.names=FALSE, col.names=FALSE, sep=',', quote="FALSE")\n\
i	
q(save='no')" > ./tmp.R

	Rscript ./tmp.R > ./NULL
	rm ./tmp.R
	rm ./NULL

	echo -e "--------------------------------------------" > ./sas-b/line.txt
	
	awk -F, '{ printf "%4d    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./sas-b/sas-b-res-${i}.dat > ./sas-b/tmp.txt
	mv ./sas-b/tmp.txt ./sas-b/sas-b-res-${i}.dat

	awk -F, '{ printf "%3s    %11.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./sas-b/sas-b-res-${i}_stats.dat > ./sas-b/sas-b-res-${i}_stats2.dat
	
	cat ./sas-b/sas-b-res-${i}.dat ./sas-b/line.txt ./sas-b/sas-b-res-${i}_stats2.dat > ./sas-b/tmp.txt
	mv ./sas-b/tmp.txt ./sas-b/sas-b-res-${i}.dat

	sed -i 's/ SD/SD /' ./sas-b/sas-b-res-${i}.dat
	rm ./sas-b/sas-b-res-${i}_stats2.dat 
done

echo " " > ./sas-b/sas-b-res.dat

for i in $resB
do
	ave_1=$(grep 'AVE' ./sas-b/sas-b-res-${i}_stats.dat | awk -F, '{print $2}')
	ave_2=$(grep 'AVE' ./sas-b/sas-b-res-${i}_stats.dat | awk -F, '{print $3}')
	ave_3=$(grep 'AVE' ./sas-b/sas-b-res-${i}_stats.dat | awk -F, '{print $4}')
	
	echo $i","$ave_1","$ave_2","$ave_3 >> ./sas-b/sas-b-res.dat
done

rm ./sas-b/*_stats.dat

sed -i -e "1d" ./sas-b/sas-b-res.dat

echo -e "sas <- read.csv('./sas-b/sas-b-res.dat', header=FALSE)\n\
\n\
sas_sum<-format(round(colSums(sas[,2:4]),4), nsmall=4)\n\
sas_line <- c(\"TOT\",sas_sum)\n\
sas_line <- as.character(sas_line)\n\
sas_line <- t(sas_line)\n\
write.table(sas_line, './sas-b/sas-b-res_stat.dat', row.names=FALSE, col.names=FALSE, sep=',', quote=FALSE)\n\
q(save='no')" > ./tmp.R 

Rscript tmp.R
rm tmp.R

awk -F, '{ printf "%4d    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./sas-b/sas-b-res.dat > ./sas-b/tmp.txt
mv ./sas-b/tmp.txt ./sas-b/sas-b-res.dat

awk -F, '{ printf "%4s    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./sas-b/sas-b-res_stat.dat > ./sas-b/tmp.txt
mv ./sas-b/tmp.txt ./sas-b/sas-b-res_stat.dat

cat ./sas-b/sas-b-res.dat ./sas-b/line.txt ./sas-b/sas-b-res_stat.dat > ./sas-b/tmp.txt
mv ./sas-b/tmp.txt ./sas-b/sas-b-res.dat
sed -i 's/ TOT/TOT /' ./sas-b/sas-b-res.dat

rm ./sas-b/line.txt ./sas-b/sas-b-res_stat.dat
################################################################################################
for i in $both_A_B
do
	mkdir ./sas-comp/res-${i}
	counter=1

	while [ $counter -le $job_num ]
	do
		job_num_formatted=`printf %04i $counter`
		cp $current/$job_num_formatted/sas-comp/sas-comp-res-${i}.dat ./sas-comp/res-${i}/sas-comp-res-${i}-${job_num_formatted}.dat
                num_lines=$(wc -l ./sas-comp/res-${i}/sas-comp-res-${i}-${job_num_formatted}.dat | grep -Eo '[0-9]+' | head -1)
                num_lines=$((num_lines-3))
                sed -i -n -e "1,$num_lines p" ./sas-comp/res-${i}/sas-comp-res-${i}-${job_num_formatted}.dat
		counter=$((counter+1))
	done
	
	cat ./sas-comp/res-${i}/*.dat > ./sas-comp/sas-comp-res-${i}.dat
	rm -r ./sas-comp/res-${i}

	sed -i 's/[[:space:]]\{1,\}/,/g' ./sas-comp/sas-comp-res-${i}.dat
        sed -i 's/^,//g' ./sas-comp/sas-comp-res-${i}.dat

	echo -e "sas_comp <- read.csv('./sas-comp/sas-comp-res-${i}.dat', header=FALSE)\n\
\n\
sas_comp[,2]<-round(sas_comp[,2],4)\n\
sas_comp[,3]<-round(sas_comp[,3],4)\n\
sas_comp[,4]<-round(sas_comp[,4],4)\n\
\n\
i <- seq(1, nrow(sas_comp), by=1)\n\
sas_comp <- sas_comp[,2:4]\n\
sas_comp <- cbind(i, sas_comp)\n\
write.table(sas_comp, './sas-comp/sas-comp-res-${i}.dat', row.names=FALSE, col.names=FALSE, sep=',')\n\
\n\
ave_1<-round(mean(sas_comp[,2]),4)\n\
ave_2<-round(mean(sas_comp[,3]),4)\n\
ave_3<-round(mean(sas_comp[,4]),4)\n\
\n\
sd_1<-round(sd(sas_comp[,2]),4)\n\
sd_2<-round(sd(sas_comp[,3]),4)\n\
sd_3<-round(sd(sas_comp[,4]),4)\n\
\n\
AVE<-c(\"AVE\")\n\
SD<-c(\"SD\")\n\
\n\
row_1<-c("AVE", ave_1, ave_2, ave_3)\n\
row_2<-c("SD", sd_1, sd_2, sd_3)\n\
stats<-rbind(row_1,row_2)\n\
write.table(stats, './sas-comp/sas-comp-res-${i}_stats.dat', row.names=FALSE, col.names=FALSE, sep=',', quote="FALSE")\n\
i	
q(save='no')" > ./tmp.R

	Rscript ./tmp.R > ./NULL
	rm ./tmp.R
	rm ./NULL

	echo -e "--------------------------------------------" > ./sas-comp/line.txt
	
	awk -F, '{ printf "%4d    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./sas-comp/sas-comp-res-${i}.dat > ./sas-comp/tmp.txt
	mv ./sas-comp/tmp.txt ./sas-comp/sas-comp-res-${i}.dat

	awk -F, '{ printf "%3s    %11.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./sas-comp/sas-comp-res-${i}_stats.dat > ./sas-comp/sas-comp-res-${i}_stats2.dat
	
	cat ./sas-comp/sas-comp-res-${i}.dat ./sas-comp/line.txt ./sas-comp/sas-comp-res-${i}_stats2.dat > ./sas-comp/tmp.txt
	mv ./sas-comp/tmp.txt ./sas-comp/sas-comp-res-${i}.dat

	sed -i 's/ SD/SD /' ./sas-comp/sas-comp-res-${i}.dat
	rm ./sas-comp/sas-comp-res-${i}_stats2.dat 
done

echo " " > ./sas-comp/sas-comp-res.dat

for i in $both_A_B
do
	ave_1=$(grep 'AVE' ./sas-comp/sas-comp-res-${i}_stats.dat | awk -F, '{print $2}')
	ave_2=$(grep 'AVE' ./sas-comp/sas-comp-res-${i}_stats.dat | awk -F, '{print $3}')
	ave_3=$(grep 'AVE' ./sas-comp/sas-comp-res-${i}_stats.dat | awk -F, '{print $4}')
	
	echo $i","$ave_1","$ave_2","$ave_3 >> ./sas-comp/sas-comp-res.dat
done

rm ./sas-comp/*_stats.dat

sed -i -e "1d" ./sas-comp/sas-comp-res.dat

echo -e "sas <- read.csv('./sas-comp/sas-comp-res.dat', header=FALSE)\n\
\n\
sas_sum<-format(round(colSums(sas[,2:4]),4), nsmall=4)\n\
sas_line <- c(\"TOT\",sas_sum)\n\
sas_line <- as.character(sas_line)\n\
sas_line <- t(sas_line)\n\
write.table(sas_line, './sas-comp/sas-comp-res_stat.dat', row.names=FALSE, col.names=FALSE, sep=',', quote=FALSE)\n\
q(save='no')" > ./tmp.R 

Rscript tmp.R
rm tmp.R

awk -F, '{ printf "%4d    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./sas-comp/sas-comp-res.dat > ./sas-comp/tmp.txt
mv ./sas-comp/tmp.txt ./sas-comp/sas-comp-res.dat

awk -F, '{ printf "%4s    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./sas-comp/sas-comp-res_stat.dat > ./sas-comp/tmp.txt
mv ./sas-comp/tmp.txt ./sas-comp/sas-comp-res_stat.dat

cat ./sas-comp/sas-comp-res.dat ./sas-comp/line.txt ./sas-comp/sas-comp-res_stat.dat > ./sas-comp/tmp.txt
mv ./sas-comp/tmp.txt ./sas-comp/sas-comp-res.dat
sed -i 's/ TOT/TOT /' ./sas-comp/sas-comp-res.dat

rm ./sas-comp/line.txt ./sas-comp/sas-comp-res_stat.dat
################################################################################################
mkdir tmp 

counter=1

while [ $counter -le $job_num ]
do
        job_num_formatted=`printf %04i $counter`
        cp $current/$job_num_formatted/total/buried-sasa.dat ./tmp/buried-sasa-${job_num_formatted}.dat
        sed -i 's/[[:space:]]\{1,\}/,/g' ./tmp/buried-sasa-${job_num_formatted}.dat
        sed -i 's/^,//g' ./tmp/buried-sasa-${job_num_formatted}.dat
        counter=$((counter+1))
done

unset counter job_num_formatted

cat ./tmp/* > ./total/buried-sasa.dat

echo -e "buried <- read.csv('./total/buried-sasa.dat', header=FALSE)\n\
\n\
i <- seq(1, nrow(buried), by=1)\n\
buried <- buried[,2:6]\n\
buried <- cbind(i, buried)\n\
write.table(buried, './total/buried-sasa.dat', row.names=FALSE, col.names=FALSE, sep=',', quote=FALSE)\n\
q(save='no')" > ./tmp.R

Rscript tmp.R
rm tmp.R

sed -i 's/^/ /' ./total/buried-sasa.dat
sed -i 's/,/  /' ./total/buried-sasa.dat
sed -i 's/,/  /' ./total/buried-sasa.dat
sed -i 's/,/  /' ./total/buried-sasa.dat
sed -i 's/,/ /' ./total/buried-sasa.dat
sed -i 's/,/ /' ./total/buried-sasa.dat

rm -r ./tmp
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
                cp $current/$job_num_formatted/solv-a/solv-a-frame-*.dat ./solv-a/.
        elif [ $counter -lt $job_num ]
        then 
                job_num_formatted=`printf %04i $counter`
                multiplier=$(((counter-1) * frames_per_job))
                
                for i in $(seq 1 $frames_per_job)
                do
                        tmp_num=$((i+multiplier))
                        cp $current/$job_num_formatted/solv-a/solv-a-frame-${i}.dat ./solv-a/solv-a-frame-${tmp_num}.dat                      
                done
        else    
                job_num_formatted=`printf %04i $counter`
                multiplier=$(((counter-1) * frames_per_job))
                
                end=$((frame_num-multiplier))

                for i in $(seq 1 $end)
                do
                        tmp_num=$((i+multiplier))
                        cp $current/$job_num_formatted/solv-a/solv-a-frame-${i}.dat ./solv-a/solv-a-frame-${tmp_num}.dat
                done
        fi

        counter=$((counter+1))
done

unset counter i job_num_formatted multiplier end_multiplier end tmp_num
################################################################################################
for i in $resA
do
	mkdir ./solv-a/res-${i}
	counter=1

	while [ $counter -le $job_num ]
	do
		job_num_formatted=`printf %04i $counter`
		cp $current/$job_num_formatted/solv-a/solv-a-res-${i}.dat ./solv-a/res-${i}/solv-a-res-${i}-${job_num_formatted}.dat
                num_lines=$(wc -l ./solv-a/res-${i}/solv-a-res-${i}-${job_num_formatted}.dat | grep -Eo '[0-9]+' | head -1)
                num_lines=$((num_lines-3))
                sed -i -n -e "1,$num_lines p" ./solv-a/res-${i}/solv-a-res-${i}-${job_num_formatted}.dat	
		counter=$((counter+1))
	done
	
	cat ./solv-a/res-${i}/*.dat > ./solv-a/solv-a-res-${i}.dat
	rm -r ./solv-a/res-${i}

	sed -i 's/[[:space:]]\{1,\}/,/g' ./solv-a/solv-a-res-${i}.dat
        sed -i 's/^,//g' ./solv-a/solv-a-res-${i}.dat

	echo -e "solv_a <- read.csv('./solv-a/solv-a-res-${i}.dat', header=FALSE)\n\
\n\
solv_a[,2]<-round(solv_a[,2],4)\n\
solv_a[,3]<-round(solv_a[,3],4)\n\
solv_a[,4]<-round(solv_a[,4],4)\n\
\n\
i <- seq(1, nrow(solv_a), by=1)\n\
solv_a <- solv_a[,2:4]\n\
solv_a <- cbind(i, solv_a)\n\
write.table(solv_a, './solv-a/solv-a-res-${i}.dat', row.names=FALSE, col.names=FALSE, sep=',')\n\
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
write.table(stats, './solv-a/solv-a-res-${i}_stats.dat', row.names=FALSE, col.names=FALSE, sep=',', quote="FALSE")\n\
i	
q(save='no')" > ./tmp.R

	Rscript ./tmp.R > ./NULL
	rm ./tmp.R
	rm ./NULL

	echo -e "--------------------------------------------" > ./solv-a/line.txt
	
	awk -F, '{ printf "%4d    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./solv-a/solv-a-res-${i}.dat > ./solv-a/tmp.txt
	mv ./solv-a/tmp.txt ./solv-a/solv-a-res-${i}.dat

	awk -F, '{ printf "%3s    %11.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./solv-a/solv-a-res-${i}_stats.dat > ./solv-a/solv-a-res-${i}_stats2.dat
	
	cat ./solv-a/solv-a-res-${i}.dat ./solv-a/line.txt ./solv-a/solv-a-res-${i}_stats2.dat > ./solv-a/tmp.txt
	mv ./solv-a/tmp.txt ./solv-a/solv-a-res-${i}.dat

	sed -i 's/ SD/SD /' ./solv-a/solv-a-res-${i}.dat
	rm ./solv-a/solv-a-res-${i}_stats2.dat 
done

echo " " > ./solv-a/solv-a-res.dat

for i in $resA
do
	ave_1=$(grep 'AVE' ./solv-a/solv-a-res-${i}_stats.dat | awk -F, '{print $2}')
	ave_2=$(grep 'AVE' ./solv-a/solv-a-res-${i}_stats.dat | awk -F, '{print $3}')
	ave_3=$(grep 'AVE' ./solv-a/solv-a-res-${i}_stats.dat | awk -F, '{print $4}')
	
	echo $i","$ave_1","$ave_2","$ave_3 >> ./solv-a/solv-a-res.dat
done

rm ./solv-a/*_stats.dat

sed -i -e "1d" ./solv-a/solv-a-res.dat

echo -e "sas <- read.csv('./solv-a/solv-a-res.dat', header=FALSE)\n\
\n\
sas_sum<-format(round(colSums(sas[,2:4]),4), nsmall=4)\n\
sas_line <- c(\"TOT\",sas_sum)\n\
sas_line <- as.character(sas_line)\n\
sas_line <- t(sas_line)\n\
write.table(sas_line, './solv-a/solv-a-res_stat.dat', row.names=FALSE, col.names=FALSE, sep=',', quote=FALSE)\n\
q(save='no')" > ./tmp.R 

Rscript tmp.R
rm tmp.R

awk -F, '{ printf "%4d    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./solv-a/solv-a-res.dat > ./solv-a/tmp.txt
mv ./solv-a/tmp.txt ./solv-a/solv-a-res.dat

awk -F, '{ printf "%4s    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./solv-a/solv-a-res_stat.dat > ./solv-a/tmp.txt
mv ./solv-a/tmp.txt ./solv-a/solv-a-res_stat.dat

cat ./solv-a/solv-a-res.dat ./solv-a/line.txt ./solv-a/solv-a-res_stat.dat > ./solv-a/tmp.txt
mv ./solv-a/tmp.txt ./solv-a/solv-a-res.dat
sed -i 's/ TOT/TOT /' ./solv-a/solv-a-res.dat

rm ./solv-a/line.txt ./solv-a/solv-a-res_stat.dat
################################################################################################
counter=1

while [ $counter -le $job_num ]
do

        if [ $counter -le 1 ]
        then 
                job_num_formatted=`printf %04i $counter`
                cp $current/$job_num_formatted/solv-b/solv-b-frame-*.dat ./solv-b/.
        elif [ $counter -lt $job_num ]
        then 
                job_num_formatted=`printf %04i $counter`
                multiplier=$(((counter-1) * frames_per_job))
                
                for i in $(seq 1 $frames_per_job)
                do
                        tmp_num=$((i+multiplier))
                        cp $current/$job_num_formatted/solv-b/solv-b-frame-${i}.dat ./solv-b/solv-b-frame-${tmp_num}.dat                      
                done
        else    
                job_num_formatted=`printf %04i $counter`
                multiplier=$(((counter-1) * frames_per_job))
                
                end=$((frame_num-multiplier))

                for i in $(seq 1 $end)
                do
                        tmp_num=$((i+multiplier))
                        cp $current/$job_num_formatted/solv-b/solv-b-frame-${i}.dat ./solv-b/solv-b-frame-${tmp_num}.dat
                done
        fi

        counter=$((counter+1))
done

unset counter i job_num_formatted multiplier end_multiplier end tmp_num
################################################################################################
for i in $resB
do
	mkdir ./solv-b/res-${i}
	counter=1

	while [ $counter -le $job_num ]
	do
		job_num_formatted=`printf %04i $counter`
		cp $current/$job_num_formatted/solv-b/solv-b-res-${i}.dat ./solv-b/res-${i}/solv-b-res-${i}-${job_num_formatted}.dat
                num_lines=$(wc -l ./solv-b/res-${i}/solv-b-res-${i}-${job_num_formatted}.dat | grep -Eo '[0-9]+' | head -1)
                num_lines=$((num_lines-3))
                sed -i -n -e "1,$num_lines p" ./solv-b/res-${i}/solv-b-res-${i}-${job_num_formatted}.dat
		counter=$((counter+1))
	done
	
	cat ./solv-b/res-${i}/*.dat > ./solv-b/solv-b-res-${i}.dat
	rm -r ./solv-b/res-${i}

	sed -i 's/[[:space:]]\{1,\}/,/g' ./solv-b/solv-b-res-${i}.dat
        sed -i 's/^,//g' ./solv-b/solv-b-res-${i}.dat

	echo -e "solv_b <- read.csv('./solv-b/solv-b-res-${i}.dat', header=FALSE)\n\
\n\
solv_b[,2]<-round(solv_b[,2],4)\n\
solv_b[,3]<-round(solv_b[,3],4)\n\
solv_b[,4]<-round(solv_b[,4],4)\n\
\n\
i <- seq(1, nrow(solv_b), by=1)\n\
solv_b <- solv_b[,2:4]\n\
solv_b <- cbind(i, solv_b)\n\
write.table(solv_b, './solv-b/solv-b-res-${i}.dat', row.names=FALSE, col.names=FALSE, sep=',')\n\
\n\
ave_1<-round(mean(solv_b[,2]),4)\n\
ave_2<-round(mean(solv_b[,3]),4)\n\
ave_3<-round(mean(solv_b[,4]),4)\n\
\n\
sd_1<-round(sd(solv_b[,2]),4)\n\
sd_2<-round(sd(solv_b[,3]),4)\n\
sd_3<-round(sd(solv_b[,4]),4)\n\
\n\
AVE<-c(\"AVE\")\n\
SD<-c(\"SD\")\n\
\n\
row_1<-c("AVE", ave_1, ave_2, ave_3)\n\
row_2<-c("SD", sd_1, sd_2, sd_3)\n\
stats<-rbind(row_1,row_2)\n\
write.table(stats, './solv-b/solv-b-res-${i}_stats.dat', row.names=FALSE, col.names=FALSE, sep=',', quote="FALSE")\n\
i	
q(save='no')" > ./tmp.R

	Rscript ./tmp.R > ./NULL
	rm ./tmp.R
	rm ./NULL

	echo -e "--------------------------------------------" > ./solv-b/line.txt
	
	awk -F, '{ printf "%4d    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./solv-b/solv-b-res-${i}.dat > ./solv-b/tmp.txt
	mv ./solv-b/tmp.txt ./solv-b/solv-b-res-${i}.dat

	awk -F, '{ printf "%3s    %11.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./solv-b/solv-b-res-${i}_stats.dat > ./solv-b/solv-b-res-${i}_stats2.dat
	
	cat ./solv-b/solv-b-res-${i}.dat ./solv-b/line.txt ./solv-b/solv-b-res-${i}_stats2.dat > ./solv-b/tmp.txt
	mv ./solv-b/tmp.txt ./solv-b/solv-b-res-${i}.dat

	sed -i 's/ SD/SD /' ./solv-b/solv-b-res-${i}.dat
	rm ./solv-b/solv-b-res-${i}_stats2.dat 
done

echo " " > ./solv-b/solv-b-res.dat

for i in $resB
do
	ave_1=$(grep 'AVE' ./solv-b/solv-b-res-${i}_stats.dat | awk -F, '{print $2}')
	ave_2=$(grep 'AVE' ./solv-b/solv-b-res-${i}_stats.dat | awk -F, '{print $3}')
	ave_3=$(grep 'AVE' ./solv-b/solv-b-res-${i}_stats.dat | awk -F, '{print $4}')
	
	echo $i","$ave_1","$ave_2","$ave_3 >> ./solv-b/solv-b-res.dat
done

rm ./solv-b/*_stats.dat

sed -i -e "1d" ./solv-b/solv-b-res.dat

echo -e "sas <- read.csv('./solv-b/solv-b-res.dat', header=FALSE)\n\
\n\
sas_sum<-format(round(colSums(sas[,2:4]),4), nsmall=4)\n\
sas_line <- c(\"TOT\",sas_sum)\n\
sas_line <- as.character(sas_line)\n\
sas_line <- t(sas_line)\n\
write.table(sas_line, './solv-b/solv-b-res_stat.dat', row.names=FALSE, col.names=FALSE, sep=',', quote=FALSE)\n\
q(save='no')" > ./tmp.R 

Rscript tmp.R
rm tmp.R

awk -F, '{ printf "%4d    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./solv-b/solv-b-res.dat > ./solv-b/tmp.txt
mv ./solv-b/tmp.txt ./solv-b/solv-b-res.dat

awk -F, '{ printf "%4s    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./solv-b/solv-b-res_stat.dat > ./solv-b/tmp.txt
mv ./solv-b/tmp.txt ./solv-b/solv-b-res_stat.dat

cat ./solv-b/solv-b-res.dat ./solv-b/line.txt ./solv-b/solv-b-res_stat.dat > ./solv-b/tmp.txt
mv ./solv-b/tmp.txt ./solv-b/solv-b-res.dat
sed -i 's/ TOT/TOT /' ./solv-b/solv-b-res.dat

rm ./solv-b/line.txt ./solv-b/solv-b-res_stat.dat
################################################################################################
counter=1

while [ $counter -le $job_num ]
do

        if [ $counter -le 1 ]
        then 
                job_num_formatted=`printf %04i $counter`
                cp $current/$job_num_formatted/solv-comp/solv-comp-frame-*.dat ./solv-comp/.
        elif [ $counter -lt $job_num ]
        then 
                job_num_formatted=`printf %04i $counter`
                multiplier=$(((counter-1) * frames_per_job))
                
                for i in $(seq 1 $frames_per_job)
                do
                        tmp_num=$((i+multiplier))
                        cp $current/$job_num_formatted/solv-comp/solv-comp-frame-${i}.dat ./solv-comp/solv-comp-frame-${tmp_num}.dat                      
                done
        else    
                job_num_formatted=`printf %04i $counter`
                multiplier=$(((counter-1) * frames_per_job))
                
                end=$((frame_num-multiplier))

                for i in $(seq 1 $end)
                do
                        tmp_num=$((i+multiplier))
                        cp $current/$job_num_formatted/solv-comp/solv-comp-frame-${i}.dat ./solv-comp/solv-comp-frame-${tmp_num}.dat
                done
        fi

        counter=$((counter+1))
done

unset counter i job_num_formatted multiplier end_multiplier end tmp_num
################################################################################################
for i in $both_A_B
do
	mkdir ./solv-comp/res-${i}
	counter=1

	while [ $counter -le $job_num ]
	do
		job_num_formatted=`printf %04i $counter`
		cp $current/$job_num_formatted/solv-comp/solv-comp-res-${i}.dat ./solv-comp/res-${i}/solv-comp-res-${i}-${job_num_formatted}.dat
                num_lines=$(wc -l ./solv-comp/res-${i}/solv-comp-res-${i}-${job_num_formatted}.dat | grep -Eo '[0-9]+' | head -1)
                num_lines=$((num_lines-3))
                sed -i -n -e "1,$num_lines p" ./solv-comp/res-${i}/solv-comp-res-${i}-${job_num_formatted}.dat
		counter=$((counter+1))
	done
	
	cat ./solv-comp/res-${i}/*.dat > ./solv-comp/solv-comp-res-${i}.dat
	rm -r ./solv-comp/res-${i}

	sed -i 's/[[:space:]]\{1,\}/,/g' ./solv-comp/solv-comp-res-${i}.dat
        sed -i 's/^,//g' ./solv-comp/solv-comp-res-${i}.dat

	echo -e "solv_comp <- read.csv('./solv-comp/solv-comp-res-${i}.dat', header=FALSE)\n\
\n\
solv_comp[,2]<-round(solv_comp[,2],4)\n\
solv_comp[,3]<-round(solv_comp[,3],4)\n\
solv_comp[,4]<-round(solv_comp[,4],4)\n\
\n\
i <- seq(1, nrow(solv_comp), by=1)\n\
solv_comp <- solv_comp[,2:4]\n\
solv_comp <- cbind(i, solv_comp)\n\
write.table(solv_comp, './solv-comp/solv-comp-res-${i}.dat', row.names=FALSE, col.names=FALSE, sep=',')\n\
\n\
ave_1<-round(mean(solv_comp[,2]),4)\n\
ave_2<-round(mean(solv_comp[,3]),4)\n\
ave_3<-round(mean(solv_comp[,4]),4)\n\
\n\
sd_1<-round(sd(solv_comp[,2]),4)\n\
sd_2<-round(sd(solv_comp[,3]),4)\n\
sd_3<-round(sd(solv_comp[,4]),4)\n\
\n\
AVE<-c(\"AVE\")\n\
SD<-c(\"SD\")\n\
\n\
row_1<-c("AVE", ave_1, ave_2, ave_3)\n\
row_2<-c("SD", sd_1, sd_2, sd_3)\n\
stats<-rbind(row_1,row_2)\n\
write.table(stats, './solv-comp/solv-comp-res-${i}_stats.dat', row.names=FALSE, col.names=FALSE, sep=',', quote="FALSE")\n\
i	
q(save='no')" > ./tmp.R

	Rscript ./tmp.R > ./NULL
	rm ./tmp.R
	rm ./NULL

	echo -e "--------------------------------------------" > ./solv-comp/line.txt
	
	awk -F, '{ printf "%4d    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./solv-comp/solv-comp-res-${i}.dat > ./solv-comp/tmp.txt
	mv ./solv-comp/tmp.txt ./solv-comp/solv-comp-res-${i}.dat

	awk -F, '{ printf "%3s    %11.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./solv-comp/solv-comp-res-${i}_stats.dat > ./solv-comp/solv-comp-res-${i}_stats2.dat
	
	cat ./solv-comp/solv-comp-res-${i}.dat ./solv-comp/line.txt ./solv-comp/solv-comp-res-${i}_stats2.dat > ./solv-comp/tmp.txt
	mv ./solv-comp/tmp.txt ./solv-comp/solv-comp-res-${i}.dat

	sed -i 's/ SD/SD /' ./solv-comp/solv-comp-res-${i}.dat
	rm ./solv-comp/solv-comp-res-${i}_stats2.dat 
done

echo " " > ./solv-comp/solv-comp-res.dat

for i in $both_A_B
do
	ave_1=$(grep 'AVE' ./solv-comp/solv-comp-res-${i}_stats.dat | awk -F, '{print $2}')
	ave_2=$(grep 'AVE' ./solv-comp/solv-comp-res-${i}_stats.dat | awk -F, '{print $3}')
	ave_3=$(grep 'AVE' ./solv-comp/solv-comp-res-${i}_stats.dat | awk -F, '{print $4}')
	
	echo $i","$ave_1","$ave_2","$ave_3 >> ./solv-comp/solv-comp-res.dat
done

rm ./solv-comp/*_stats.dat

sed -i -e "1d" ./solv-comp/solv-comp-res.dat

echo -e "sas <- read.csv('./solv-comp/solv-comp-res.dat', header=FALSE)\n\
\n\
sas_sum<-format(round(colSums(sas[,2:4]),4), nsmall=4)\n\
sas_line <- c(\"TOT\",sas_sum)\n\
sas_line <- as.character(sas_line)\n\
sas_line <- t(sas_line)\n\
write.table(sas_line, './solv-comp/solv-comp-res_stat.dat', row.names=FALSE, col.names=FALSE, sep=',', quote=FALSE)\n\
q(save='no')" > ./tmp.R 

Rscript tmp.R
rm tmp.R

awk -F, '{ printf "%4d    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./solv-comp/solv-comp-res.dat > ./solv-comp/tmp.txt
mv ./solv-comp/tmp.txt ./solv-comp/solv-comp-res.dat

awk -F, '{ printf "%4s    %10.4f %10.4f %10.4f \n", $1, $2, $3, $4 }' ./solv-comp/solv-comp-res_stat.dat > ./solv-comp/tmp.txt
mv ./solv-comp/tmp.txt ./solv-comp/solv-comp-res_stat.dat

cat ./solv-comp/solv-comp-res.dat ./solv-comp/line.txt ./solv-comp/solv-comp-res_stat.dat > ./solv-comp/tmp.txt
mv ./solv-comp/tmp.txt ./solv-comp/solv-comp-res.dat
sed -i 's/ TOT/TOT /' ./solv-comp/solv-comp-res.dat

rm ./solv-comp/line.txt ./solv-comp/solv-comp-res_stat.dat
################################################################################################
mkdir tmp

counter=1

while [ $counter -le $job_num ]
do
        job_num_formatted=`printf %04i $counter`
        cp $current/$job_num_formatted/total/solv-a-global.dat ./tmp/solv-a-global-${job_num_formatted}.dat
        sed -i 's/[[:space:]]\{1,\}/,/g' ./tmp/solv-a-global-${job_num_formatted}.dat
        sed -i 's/^,//g' ./tmp/solv-a-global-${job_num_formatted}.dat
        counter=$((counter+1))
done

unset counter job_num_formatted

cat $current/tmp/* > ./total/solv-a-global.dat

echo -e "solv_a_global <- read.csv('./total/solv-a-global.dat', header=FALSE)\n\
\n\
i <- seq(1, nrow(solv_a_global), by=1)\n\
solv_a_global <- solv_a_global[,2]\n\
solv_a_global <- cbind(i, solv_a_global)\n\
write.table(solv_a_global, './total/solv-a-global.dat', row.names=FALSE, col.names=FALSE, sep=',')\n\
q(save='no')" > ./tmp.R

Rscript tmp.R
rm tmp.R

sed -i 's/^/ /' ./total/solv-a-global.dat
sed -i 's/,/ /' ./total/solv-a-global.dat

rm -r ./tmp
################################################################################################
mkdir tmp

counter=1

while [ $counter -le $job_num ]
do
        job_num_formatted=`printf %04i $counter`
        cp $current/$job_num_formatted/total/solv-b-global.dat ./tmp/solv-b-global-${job_num_formatted}.dat
        sed -i 's/[[:space:]]\{1,\}/,/g' ./tmp/solv-b-global-${job_num_formatted}.dat
        sed -i 's/^,//g' ./tmp/solv-b-global-${job_num_formatted}.dat
        counter=$((counter+1))
done

unset counter job_num_formatted

cat $current/tmp/* > ./total/solv-b-global.dat

echo -e "solv_b_global <- read.csv('./total/solv-b-global.dat', header=FALSE)\n\
\n\
i <- seq(1, nrow(solv_b_global), by=1)\n\
solv_b_global <- solv_b_global[,2]\n\
solv_b_global <- cbind(i, solv_b_global)\n\
write.table(solv_b_global, './total/solv-b-global.dat', row.names=FALSE, col.names=FALSE, sep=',')\n\
q(save='no')" > ./tmp.R

Rscript tmp.R
rm tmp.R

sed -i 's/^/ /' ./total/solv-b-global.dat
sed -i 's/,/ /' ./total/solv-b-global.dat

rm -r ./tmp
################################################################################################
mkdir tmp

counter=1

while [ $counter -le $job_num ]
do
        job_num_formatted=`printf %04i $counter`
        cp $current/$job_num_formatted/total/solv-comp-global.dat ./tmp/solv-comp-global-${job_num_formatted}.dat
        sed -i 's/[[:space:]]\{1,\}/,/g' ./tmp/solv-comp-global-${job_num_formatted}.dat
        sed -i 's/^,//g' ./tmp/solv-comp-global-${job_num_formatted}.dat
        counter=$((counter+1))
done

unset counter job_num_formatted

cat $current/tmp/* > ./total/solv-comp-global.dat

echo -e "solv_comp_global <- read.csv('./total/solv-comp-global.dat', header=FALSE)\n\
\n\
i <- seq(1, nrow(solv_comp_global), by=1)\n\
solv_comp_global <- solv_comp_global[,2]\n\
solv_comp_global <- cbind(i, solv_comp_global)\n\
write.table(solv_comp_global, './total/solv-comp-global.dat', row.names=FALSE, col.names=FALSE, sep=',')\n\
q(save='no')" > ./tmp.R

Rscript tmp.R
rm tmp.R

sed -i 's/^/ /' ./total/solv-comp-global.dat
sed -i 's/,/ /' ./total/solv-comp-global.dat

rm -r ./tmp
################################################################################################
$perl $perl_scripts/calc-bind-global.prl  > ./log/calc-bind-global.log
$perl $perl_scripts/calc-bind-byres.prl  > ./log/calc-bind-byres.log
$perl $perl_scripts/calc-bind-byres-stat.prl > ./log/calc-bind-byres-stat.log

# Put values into pdb B-factor column
$scripts/put_mmgbsa_in_pdb_beta.prl data/complex.pdb  binding_sc.dat > binding_sc.pdb 
$scripts/put_mmgbsa_in_pdb_beta.prl data/complex.pdb  binding_bb.dat > binding_bb.pdb 
$scripts/put_mmgbsa_in_pdb_beta.prl data/complex.pdb  binding_all.dat > binding_all.pdb 


echo "Done."
exit
