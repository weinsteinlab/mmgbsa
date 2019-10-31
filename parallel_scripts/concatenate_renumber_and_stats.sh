#!/bin/bash -l

################################################################################################

# Arguments :
fname=$1
current=$2
job_num=$3

source $mmgbsa_path/scripts/setenv.sh

# File name without extention
froot="${fname%.*}"
ftmp=${froot}.tmp

################################################################################################

counter=1

rm -f $ftmp
while [ $counter -le $job_num ]
do
	job_num_formatted=`printf %04i $counter`
	awk '($1~/[0-9]/)' $current/$job_num_formatted/$fname >> $ftmp
	counter=$((counter+1))
done

# Remove trailing spaces
sed -i 's/[ \t]*$//' $ftmp
# Replace spaces with commas
sed -i 's/[[:space:]]\{1,\}/,/g' $ftmp
# Remove first comma
sed -i 's/^,//g;s/,^//g' $ftmp

$perl_scripts/renumber_and_stats.prl $ftmp > $fname

#rm $ftmp












