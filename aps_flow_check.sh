#!/bin/bash 

. helper.sh


export l1=`cat $INPUTFILE|tail -n +2`
#export l2=`cat $INPUTFILE|tail -n +2|tr -s "\t" " "|sed 's/[ \t]*$//'|grep " " |tr -s " " "-"|grep -`
while read i2 ; do
      export tmp=`echo $i2|tr -s "\t" " "|sed 's/[ \t]*$//'|tr " " "-"`
      export i=`echo ${tmp}_${PROCESS_LINE}`
      export l2=`echo $l2 $i`
done < <(cat $INPUTFILE|tail -n +2|tr -s "\t" " "|sed 's/[ \t]*$//' | tr -s " " "-"|grep - )



function show_help
{
	echo "-d dir 		only check directory dir."
	echo "-s script 	only check script."
	echo "-i suffix  	writes information about the jobs, one file per script, using scriptname with suffix as the filename."
        echo "			It uses the *.get_info scripts to extract the info."
	echo "-a 		check all scripts in case of error, doesn't stops at the first error of a sample."
}

OPTIND=1
unset CHECK
export FILTER_SCRIPTS="[1-9]*.sh"
export INFOFILE=information.out
export INFO=false
export VERBOSE=false
export CHECK_AFTER_ERR=false
export LOGERR="commands_to_clean_errors.txt"

let nerrors=0
let unexec=0
let nchecks=0

while getopts "h?vd:s:i:a" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    a)  CHECK_AFTER_ERR=true
        ;;
    v)  VERBOSE=true
        ;;
    d)  l1=$OPTARG
        unset l2
	;;
    i)  INFOFILE=$OPTARG
	INFO=true
	for i in *${INFOFILE} ; do 
		mv --backup=t $i ${i}.bck
	done
        ;;
    esac
done

shift $((OPTIND-1))
[ "$1" = "--" ] && shift

echo `date` Begin check >> $LOGERR



function trabajo_con_nombre
{
  check=`grep "#SBATCH -J " $1|sed "s/#SBATCH -J //"`
  if echo $check | grep "^[1-9]" > /dev/null 2>&1 ; then
    export JOB_NAME="$check"
    return 0
  fi
  unset JOB_NAME
  return 1
}

lista_scripts=`cd ${JOB_SOURCE};ls $FILTER_SCRIPTS 2> /dev/null`
lista_unify_scripts=`cd ${JOB_SOURCE};ls [1-9]*${SYNC_JOB}*sh 2> /dev/null`

if test `echo $lista_unify_scripts |wc -w` -gt 5 ; then 
  echo
  echo WARNING: there are more than five sync jobs \($SYNC_JOB\) are you sure ?
  echo Probable the workflow can be made in another, better, way.
  echo 
  echo Currently there are: $lista_unify_scripts
fi

if test `echo $lista_scripts |wc -w` -eq 0 ; then
  echo
  echo ERROR: there are no jobs in the dir \${JOB_SOURCE} :
  echo ${JOB_SOURCE}
  echo Maybe it is wrong ?
  exit 1
fi

# chequea tha ouput names, so they are not repeated:
export rep_out=`grep -h -- "CH --output=" ${JOB_SOURCE}/*sh|sort |uniq -c|sort -n|tail -1|awk '{print $1}'`
if test $rep_out != 1 ; then
  echo In the scripts the filenames of the OUTPUT files should be unique, but this one is repeated in several scripts :
  grep -h -- "CH --output=" ${JOB_SOURCE}/*sh|sort |uniq -c|sort -n|egrep -v ^" *"1
  outff=`grep -h -- "CH --output=" ${JOB_SOURCE}/*sh|sort |uniq -c|sort -n|egrep -v ^" *"1|awk '{print $3}'` 
  echo
  echo It is repeated in the files:
  echo
  grep -- "$outff" ${JOB_SOURCE}/*sh |awk -F ':' '{print $1}'
  echo
  echo Also check the ERROR filename in those scripts, as they are probably also wrong. Put the right output filenames for each script in all cases.
  exit 1
fi

PROCESS_LINE_JOBS=`echo $lista_scripts|grep "$PROCESS_LINE"`

greatest_size_job=5
greatest_size_job_name=""

for job in $lista_scripts ; do
  # checks if this script process all the line at the same time
#  if echo $job| grep $PROCESS_LINE > /dev/null ; then
 #   for i in `cat $INPUTFILE|tail -n +2|tr -s "\t" " "|sed 's/[ \t]*$//'|tr -s " " "·"`; do
      let index=1
#echo leido $i2 del file input
      for sam in `echo $i2|tr "·" " "` ; do
        sample[${index}]=$sam
        let index=${index}+1
      done
      trabajo_con_nombre ${JOB_SOURCE}/$job
      if ! echo ${job:0:1}| grep "[1-9]" > /dev/null ; then 
           echo Problem in job $job :
	   echo The job name should begin with a number that indicates its place in the flow. 
	   echo
	   echo For example, in this case, inside the script $job
	   echo  it should say:
	   echo \#SBATCH -J $job
	   echo
	   $exit 1
      fi
      if ! test "${job:0:1}" -eq "${JOB_NAME:0:1}" ; then 
           echo Problem in job $job :
           echo 
	   if ! test -z "$JOB_NAME" ; then 
		echo The job name is $JOB_NAME
	   fi
	   echo  It should begin with the same number that the job inside the flow.
	   echo 
	   echo For example, in this case, inside the script $job
	   echo  it should say:
	   echo \#SBATCH -J $job
	   echo
	   exit 1
      fi
      if test `echo $JOB_NAME|wc -c` -gt $greatest_size_job && ! echo $JOB_NAME|grep $SYNC_JOB > /dev/null ; then 
           greatest_size_job=`echo $JOB_NAME|wc -c` 
           greatest_size_name=$JOB_NAME
      fi
#      if ! echo $job|grep $SYNC_JOB && echo $JOB_NAME |grep SAMPLE ; then
#	echo Problem in job $job :
#	echo Job name should include SAMPLE, so it contains the concrete sample to be used.
#	exit 1
#      fi
done


# checks input file

merge_lines=`cat $INPUTFILE|tail -n +2|tr -s "\t" " "|sed 's/[ \t]*$//' |tr " " "-" |sort|uniq|wc -l`
lines=`cat $INPUTFILE|tail -n +2|uniq|wc -l`

if ( test $merge_lines -ne $lines ) ; then 
   echo There is a problem in the input file $INPUTFILE with the lines.
   echo For example, some lines are repeated.
   echo lines counted in total: $lines, sorted and merged : $merge_lines
   exit 1 
fi

conditions=`cat $INPUTFILE|head -1|wc -w`
let index=0
cat $INPUTFILE|tail -n +2|tr -s "\t" " "|sed 's/[ \t]*$//' | while read i2 ; do 
let index=index+1
samples_in_line=`echo $i2 |wc -w` 
if test $samples_in_line -ne $conditions ; then 
  echo In input file: $INPUTFILE
  echo there is an incorrect number of samples in line $index
  echo The conditions are: 
  head -1 $INPUTFILE
  echo 
  echo Line $index contains: 
  echo $i2
  exit 1
fi
  for sample in `echo $i2` ; do
    let job_chars=${greatest_size_job}+`echo $sample |wc -c`
    if test ${job_chars} -gt 45 ; then 
       echo The size of the name of the job $greatest_size_name is too large, take too much characters.
       echo Please, use job names of less size, for example, use 1_clean.sh instead of
       echo 1_step_where_cleaning_is_done.sh
       echo Contact rlarrosa@uma.es if there are problems with that.
       echo
       exit 1
    fi
  done
done

exit $?

