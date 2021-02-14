# In this file are included validations. support functions and variables
# declaration that the program needs

export CACHE_SQUEUE_FILE=/tmp/squeue_cache.`whoami`.tmp
export CACHE_SQUEUE_FILE_BN=`basename $CACHE_SQUEUE_FILE`

# Validations of some needed variables before the process starts

# Checking variable $LOG

if test "x$LOG" == "x" ; then
  export LOG=$PWD/works.log
fi

# Checking variable $LOGGER

if test "x$LOGERR" == "x" ; then
  export LOGERR=$PWD/works_trace.err
fi

# Checking variable $JOB_SOURCE

if test "x$JOB_SOURCE" == "x" ; then
  echo Error: path of work files must be specified in env var JOB_SOURCE
  echo For example:
  echo export JOB_SOURCE=${PWD}/worksteps
  exit 2
else if test "${JOB_SOURCE:0:1}" != "/" && test "${JOB_SOURCE:0:1}" != "~" ; then
   export REAL_JOB_SOURCE=$PWD/${JOB_SOURCE}
   else 
   export REAL_JOB_SOURCE=${JOB_SOURCE}
   fi
fi

# Checking variable $EXPERIMENT

if test -z "$EXPERIMENT" ; then
	echo ERROR: environment variable EXPERIMENT not defined.
	echo It should be defined inside an ini*.sh file.
	exit 2
fi

# Checking if the init file exists for the current experiment

if ! grep -v \# ini*.sh| grep ${EXPERIMENT} > /dev/null; then
        echo ERROR : current directory does not contain an init file for experiment ${EXPERIMENT}
        exit 2
fi

# Checking variable $REFERENCE_GENOME, if not this variable will take the default value

if test "x$REFERENCE_GENOME" == "x" ; then
  export REFERENCE_GENOME=/mnt/home/soft/human/data/hg38/hgdownload.cse.ucsc.edu/goldenPath/hg38/bigZips
  echo Warning: Path to reference genome not defined, defaults to $REFERENCE_GENOME
fi

# Checking variable $DATA_ORIGIN

if test "x$DATA_ORIGIN" == "x" ; then
  echo Error: path of data files must be specified in env var DATA_ORIGIN
  echo example:
  echo export DATA_ORIGIN=/mnt/home/users/pab/user1/data
  exit 3
fi 

# Checking variable $PROCESS_LINE. This variable is used to know when a script is going to use
# more than one sample. If we need to compare samples a new directory will be created where
# the comparations will be allocated. In no value has been specified for this variable it will
# take the default value as 'compare'.

if test "x$PROCESS_LINE" == "x" ; then
  export PROCESS_LINE=compare
fi

# jobs that contain this string make a "sync" job, so it uses data from all jobs until now
# They are contained in a dir called with their name minus .sh

if test "x$SYNC_JOB" == "x" ; then
  export SYNC_JOB=unify
fi

# directories prefix
export DIR_PREFIX=SAMPLE_

# se le pasa el script a ejecutar y devuelve el Job ID, si no estaba en ejecución.
# $1 es el fichero a ejecutar
# $2 el sample id sobre el que se va a ejecutar

# Checking variable $INPUTFILE. We check that the file exists and it is a text file. 
# Apart of that we check if it has content.

if test "x$INPUTFILE" == "x" ; then   
  echo Error: path of file that contains sample info must be specified in environment variable INPUTFILE
  echo example:
  echo export INPUTFILE=example_list.txt
  exit 4
fi

if ! [ -f "$INPUTFILE" ]
then
  echo Error: INPUTFILE variable does not match with a text file
  echo example:
  echo export INPUTFILE=example_list.txt
  exit 4
fi

lines=$(wc -l $INPUTFILE)

if [[ ${lines:0:1} -lt 2 ]]
then
  echo Error: $INPUTFILE is empty. Please add the information before start
  exit 4
fi

# This function will show the jobs of the chosen user in the system queue

function cache_squeue
{
   if ! test -s  ${CACHE_SQUEUE_FILE} || find /tmp/ -maxdepth 1 -iname $CACHE_SQUEUE_FILE_BN -mmin +1 |grep $CACHE_SQUEUE_FILE_BN 2> /dev/null ; then
      squeue -u `whoami` -o "%.7i %.9P %.30j %.18u %.8t %.6C %.6D %.9r %Q %q %L %N" > ${CACHE_SQUEUE_FILE}.tmp
      mv  ${CACHE_SQUEUE_FILE}.tmp  ${CACHE_SQUEUE_FILE}
   fi
   cat $CACHE_SQUEUE_FILE
}

# The next function will display the job information and save it in a tmp file. The input is the job id.

function cache_scontrol
{
  jid=$1
  export now=`date +%s`
  if find /tmp/sacuigscdsa43_cache  -maxdepth 1 -iname '$jid.bor' -mmin +1 2> /dev/null ; then
    scontrol show job $jid > /tmp/sacuigscdsa43_cache/$jid.bor
    export updated=`date +%s`
  fi
  cat /tmp/sacuigscdsa43_cache/$jid.bor
}

function send
{
	unset dependence

	if test -n "$DEPEND" ; then
	   export dependence="-d afterok:$DEPEND"
	fi

	for id_job in `cache_squeue|grep $1|awk '{print $1}'`; do
	  if scontrol show job $id_job |grep `pwd -P`/$1 > /dev/null 2> /dev/null; then
	    echo `date` Job $1 is currently running on sample $2 >> $LOG
	    echo `date` Job $1 is currently running on sample $2 >> $LOGERR
	    echo `date` Job $1 is currently running on sample $2 , work $id_job
	    exit 1
	  fi
	done

  unset ADD_DEPEND

	export ADD_DEPEND=`sbatch $dependence $1 |grep -i "Submitted batch job"|awk '{print $4}'`

	echo sbatch $dependence $1 >> $LOG
}

function check_sending
{
  if ! test -n "$1" ; then
    echo $1 issue found when running $2 work on PAC1 patient
    echo $1 issue found when running $2 work on PAC1 patient >> $LOG
    exit 1
  fi
}

# The next function will check if the requested job exists in the queue system.
# Arguments must be: 1st. directory and 2nd. filename of job without sh
function work_exists
{
  if ! echo $2 |grep $SYNC_JOB > /dev/null ; then
    export ADD_DEPEND=""
    for j in `cache_squeue| grep ^[1-9]| awk '{print $1}'`; do
      if  scontrol show job $j |grep `pwd -P`/$2 > /dev/null ; then
          export ADD_DEPEND=${j}
          return 0
      fi
    done
  else 
    export ADD_DEPEND=""
# uses all path except the last dir, so it recognices the sync job from all the samples
# This way the sync job matchs in all samples, and they can recognice one job as theirs, so 
# they depend on it
    partial_dir=`pwd -P|awk -F / '{$NF=""; print $0}'|tr " " "/"`
    for j in `cache_squeue| grep ^[1-9]| awk '{print $1}'`; do
      if  scontrol show job $j |grep ${partial_dir}|grep $2 > /dev/null ; then
	     echo Job exists: $j exists in ${partial_dir} for $2 sample >> $LOG
       export ADD_DEPEND=${j}
       return 0
      fi
    done
  fi
  return 1
}

# A number indicting a step and all jobs are passed, and returns the previous step.
function previous_step
{
  actual=`echo $1|awk -F_ '{print $1}'`
  prev=`ls ${JOB_SOURCE} |sort|grep ^[1-9]| sort -nr|awk -F_ '{print $1}'|uniq |awk -F_  '{if (nex==1) {print $1;exit}; if ($1=='$actual') {nex=1}}'`
  echo $prev
}

# tiene como entrada el numero del trabajo y el 2 el dir en el que esta, que
# puede ser de los samples de los que depende separados por _, simplemente
# el sample actual, o el nombre del script si es un sync_job
function create_dependencies 
{
  unset ADD_DEPEND
  export actual=$1
  tmp=`pwd -P`
  base_dir=`dirname $tmp`
  echo checking $1 $2 $3 :  >> $LOG
  if ! (echo $2 |grep $SYNC_JOB > /dev/null ) && ! (echo $2 |grep $PROCESS_LINE > /dev/null ); then 
    echo no sync or line >> $LOG
    # if it is not a syncjob
    rm $CACHE_SQUEUE_FILE
      for jobs in `cache_squeue| grep ^[1-9]| awk '$2<'$actual' {print $1}'`; do
	  way=`scontrol show job $jobs |grep "Command="|grep ${tmp}`
          echo to check $jobs in $way >> $LOG
	  if ! test -z "$way" ; then
	    export ADD_DEPEND=`echo $ADD_DEPEND $jobs`
 	  fi
	done
    export ADD_DEPEND=`echo $ADD_DEPEND|tr " " "\n" |sort|uniq|tr "\n" " "`
    export ADD_DEPEND=`echo $ADD_DEPEND|xargs| tr " " ":"`
  else 
    # if it is a syncjob it depends upon all previous jobs
    let prev=${actual}-1
    prev_orden=`previous_step $actual`
    samples="`cat $INPUTFILE|tail -n +2` `cat $INPUTFILE|tail -n +2|tr -s "\t" " "|sed 's/[ \t]*$//'|tr -s " " "-"|grep -` `echo $SYNC_JOB`"
    for sample in $samples ; do
    	for jobs in `cache_squeue| grep $sample| grep ^[1-9]|tr "_" " "|awk '$2=='$prev_orden' {print $1}'`; do
	  way=`scontrol show job $jobs |grep "Command="|grep $base_dir|grep $sample`
	  if ! test -z "$way" ; then
  	    let name=`basename $way|tr "_" " "| awk '{print $1}'`
	    if test $name -eq $prev_orden ; then 
		export ADD_DEPEND=`echo $jobs $ADD_DEPEND`
	    fi
	  fi
	done
    done
    export ADD_DEPEND=`echo $ADD_DEPEND|tr " " "\n" |sort|uniq|tr "\n" " "`
    export ADD_DEPEND=`echo $ADD_DEPEND|xargs| tr " " ":"`
  fi
  return 0
}

function output_file
{
  check=`grep "#SBATCH --output" $2|sed "s/#SBATCH --output=//"|sed s/%J/*/`
  if ls $check > /dev/null 2>&1 ; then
    export OUTPUT_FILE="$check"
    return 0
  fi
  unset OUTPUT_FILE
  return 1
}


function work_done_successfully
{
 if test -s ${2}.check ; then 
   ./${2}.check > /dev/null
   return $?
 else
  check=`grep ^#CHECK $2|sed "s/#CHECK //"`
# If there are " in check then we suposse that it is a command that needs a string as a first argument, like a grep
  if echo $check | grep "\"" > /dev/null ; then 
    cmd=`echo $check |awk  '{split($0,a,"\"");print a[1]}'`
    chain=`echo $check|awk  '{split($0,a,"\"");print a[2]}'`
    outfiles=`echo $check|awk  '{split($0,a,"\"");print a[3]}'`
    if $cmd "${chain}" $outfiles > /dev/null 2>&1 ; then
      return 0
    else     
      return 1
    fi
  elif echo $check |grep find > /dev/null ; then
    cmd=`echo $check |awk  '{split($0,a," ");print a[1]}'`
    outfiles=`echo $check|awk  '{split($0,a," ");print a[2],a[3],a[4],a[5],a[6],a[7],a[8],a[9],a[10]}'`
    if test `$cmd $outfiles | wc -l` != 0  > /dev/null 2>&1 ; then
      return 0
    else    
      return 1
    fi
  else
    cmd=`echo $check |awk  '{split($0,a," ");print a[1]}'`
    outfiles=`echo $check|awk  '{split($0,a," ");print a[2],a[3],a[4],a[5],a[6],a[7],a[8],a[9],a[10]}'`
    if eval $cmd $outfiles > /dev/null 2>&1 ; then
      return 0
    else    
      return 1
    fi
  fi
 fi
}

