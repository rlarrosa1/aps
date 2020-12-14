# variables globales





if test "x$LOG" == "x" ; then
  export LOG=$PWD/crea_trabajos.log
fi
if test "x$LOGERR" == "x" ; then
  export LOGERR=$PWD/envia_trabajos.err
fi
export CACHE_SQUEUE_FILE=/tmp/squeue_cache.`whoami`.tmp
export CACHE_SQUEUE_FILE_BN=`basename $CACHE_SQUEUE_FILE`
if test "x$JOB_SOURCE" == "x" ; then
#  export JOB_SOURCE=originales
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

if test -z "$EXPERIMENTO" ; then
	echo ERROR: environment variable EXPERIMENTO not defined.
	echo It should be defined inside an ini*.sh file.
	exit 2
fi


if ! grep -v \# ini*.sh| grep ${EXPERIMENTO} > /dev/null; then
        echo ERROR : current dir does not contain an init file for experiment ${EXPERIMENTO}
        exit 2
fi

if test "x$GENOMA_REFERENCIA" == "x" ; then
  export GENOMA_REFERENCIA=/mnt/home/soft/human/data/hg38/hgdownload.cse.ucsc.edu/goldenPath/hg38/bigZips
  echo Warning: Path to reference genome not defined, defaults to $GENOMA_REFERENCIA
fi
if test "x$ORIGEN_DATOS" == "x" ; then
#  export ORIGEN_DATOS=/mnt/scratch/users/pab_001_uma/macarroyo/EGA/datos_originales/descomprimidos/
  echo Error: path of data files must be specified in env var ORIGEN_DATOS
  echo example:
  echo export ORIGEN_DATOS=/mnt/home/users/pab/user1/data
  exit 3
fi 
# palabra clave que se usa para saber cuando un script va a usar varias muestras.
#  Se creará un directorio nuevo para las comparaciones.
if test "x$PROCESS_LINE" == "x" ; then
  export PROCESS_LINE=compare
fi
# dentro se usarán SAMPLE_NORMAL y SAMPLE_CANCER

# jobs that contain this string make a "sync" job, so it uses data from all jobs until now
# They are contained in a dir called with their name minus .sh
if test "x$SYNC_JOB" == "x" ; then
  export SYNC_JOB=unify
fi

#if test "x${TEMPORAL_DIR}" == "x" ; then
#  echo Error: path to temporal dir must be specified in env var TEMPORAL_DIR
#  echo example:
#  echo export TEMPORAL_DIR=\${SCRATCH}/temp_dir_\${EXPERIMENTO}
#  exit 5
#fi


# para añadirlo como prefijo a los directorios
export DIR_PREFIX=SAMPLE_
# se le pasa el script a ejecutar y devuelve el Job ID, si no estaba en ejecución.
# $1 es el fichero a ejecutar
# $2 el sample id sobre el que se va a ejecutar

if test "x$INPUTFILE" == "x" ; then 
  #export INPUTFILE=lista_exomas_completa.txt
  echo Error: path of file that contains sample infoi must be specified in env var INPUTFILE
  echo example:
  echo export INPUTFILE=lista_exomas_completa.txt
  exit 4
fi

if ! [ -f "$INPUTFILE" ]
then
  echo Error: INPUTFILE variable does not match with an text file
  echo example:
  echo export INPUTFILE=lista_exomas_completa.txt
  exit 4
fi

lines=$(wc -l $INPUTFILE)

if [[ ${lines:0:1} -lt 2 ]]
then
  echo Error: $INPUTFILE is empty. Please add the information before start
  exit 4
fi

function cache_squeue
{
   if ! test -s  ${CACHE_SQUEUE_FILE} || find /tmp/ -maxdepth 1 -iname $CACHE_SQUEUE_FILE_BN -mmin +1 |grep $CACHE_SQUEUE_FILE_BN 2> /dev/null ; then
      squeue -u `whoami` -o "%.7i %.9P %.30j %.18u %.8t %.6C %.6D %.9r %Q %q %L %N" > ${CACHE_SQUEUE_FILE}.tmp
      mv  ${CACHE_SQUEUE_FILE}.tmp  ${CACHE_SQUEUE_FILE}
   fi
   cat $CACHE_SQUEUE_FILE
}

function cache_scontrol
{
   jid=$1
#   mkdir /tmp/sacuigscdsa43_cache 2> /dev/null
#   chmod 777 /tmp/sacuigscdsa43_cache
export now=`date +%s`
   if find /tmp/sacuigscdsa43_cache  -maxdepth 1 -iname '$jid.bor' -mmin +1 2> /dev/null ; then
      scontrol show job $jid > /tmp/sacuigscdsa43_cache/$jid.bor
      export updated=`date +%s`
   fi
   cat /tmp/sacuigscdsa43_cache/$jid.bor
}

function envia
{
	unset depende_de
#    	prev_orden=`previous_step $1`
	if test -n "$DEPEND" ; then
	   export depende_de="-d afterok:$DEPEND"
	fi

	for id_job in `cache_squeue|grep $1|awk '{print $1}'`; do
	  if scontrol show job $id_job |grep `pwd -P`/$1 > /dev/null 2> /dev/null; then
#	  if cache_scontrol $id_job |grep `pwd -P`/$2 > /dev/null 2> /dev/null; then
	    echo `date` ya se está ejecutando el trabajo $1 en la muestra $2 >> $LOG
	    echo `date` ya se está ejecutando el trabajo $1 en la muestra $2 >> $LOGERR
	    echo `date` ya se está ejecutando el trabajo $1 en la muestra $2 , trabajo $id_job
	    exit 1
	  fi
	done
        unset ADD_DEPEND
	export ADD_DEPEND=`sbatch $depende_de $1 |grep -i "Submitted batch job"|awk '{print $4}'`
	echo sbatch $depende_de $1 >> $LOG
}

function chequea_envio
{
  if ! test -n "$1" ; then
    echo Problema $1 al lanzar el trabajo $2 en paciente PAC1
    echo Problema $1 al lanzar el trabajo $2 en paciente PAC1 >> $LOG
    exit 1
  fi
}


# arguments must be: 1st. directory and 2nd. filename of job without sh
function existe_trabajo
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
    dir_partial=`pwd -P|awk -F / '{$NF=""; print $0}'|tr " " "/"`
    for j in `cache_squeue| grep ^[1-9]| awk '{print $1}'`; do
      if  scontrol show job $j |grep ${dir_partial}|grep $2 > /dev/null ; then
	  echo existe_job: $j dentro de ${dir_partial} en muestra $2 >> $LOG
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
function crea_dependencias 
{
  unset ADD_DEPEND
  export actual=$1
  tmp=`pwd -P`
  dir_base=`dirname $tmp`
  echo checking $1 $2 $3 :  >> $LOG
  if ! (echo $2 |grep $SYNC_JOB > /dev/null ) && ! (echo $2 |grep $PROCESS_LINE > /dev/null ); then 
    echo no sync or line >> $LOG
    # if it is not a syncjob
    rm $CACHE_SQUEUE_FILE
#    for sample in `echo $2|tr "_" " " ` ; do
#      for jobs in `cache_squeue| grep $3| grep ^[1-9]| awk '$2<'$actual' {print $1}'`; do
      for jobs in `cache_squeue| grep ^[1-9]| awk '$2<'$actual' {print $1}'`; do
	  camino=`scontrol show job $jobs |grep "Command="|grep ${tmp}`
          echo to check $jobs in $camino >> $LOG
	  if ! test -z "$camino" ; then
	    export ADD_DEPEND=`echo $ADD_DEPEND $jobs`
 	  fi
	done
#    done
    export ADD_DEPEND=`echo $ADD_DEPEND|tr " " "\n" |sort|uniq|tr "\n" " "`
    export ADD_DEPEND=`echo $ADD_DEPEND|xargs| tr " " ":"`
  else 
    # if it is a syncjob it depends upon all previous jobs
    let prev=${actual}-1
    prev_orden=`previous_step $actual`
    samples="`cat $INPUTFILE|tail -n +2` `cat $INPUTFILE|tail -n +2|tr -s "\t" " "|sed 's/[ \t]*$//'|tr -s " " "-"|grep -` `echo $SYNC_JOB`"
    for sample in $samples ; do
    	for jobs in `cache_squeue| grep $sample| grep ^[1-9]|tr "_" " "|awk '$2=='$prev_orden' {print $1}'`; do
	  camino=`scontrol show job $jobs |grep "Command="|grep $dir_base|grep $sample`
	  if ! test -z "$camino" ; then
  	    let name=`basename $camino|tr "_" " "| awk '{print $1}'`
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

function trabajo_con_fichero_salida
{
  check=`grep "#SBATCH --output" $2|sed "s/#SBATCH --output=//"|sed s/%J/*/`
  if ls $check > /dev/null 2>&1 ; then
    export OUTPUT_FILE="$check"
    return 0
  fi
  unset OUTPUT_FILE
  return 1
}


function trabajo_terminado_correctamente
{
 if test -s ${2}.check ; then 
   ./${2}.check > /dev/null
   return $?
 else
  check=`grep ^#CHECK $2|sed "s/#CHECK //"`
# If there are " in check then we suposse that it is a command that needs a string as a first argument, like a grep
  if echo $check | grep "\"" > /dev/null ; then 
    cmd=`echo $check |awk  '{split($0,a,"\"");print a[1]}'`
    cadena=`echo $check|awk  '{split($0,a,"\"");print a[2]}'`
    outfiles=`echo $check|awk  '{split($0,a,"\"");print a[3]}'`
#    echo 11job $1 $2, to check $cmd $cadena $outfiles 
#    echo CMD: $cmd "${cadena}" $outfiles
    if $cmd "${cadena}" $outfiles > /dev/null 2>&1 ; then
      return 0
    else 
    #echo no existe trabajo correcto de $1
      return 1
    fi
  elif echo $check |grep find > /dev/null ; then
    cmd=`echo $check |awk  '{split($0,a," ");print a[1]}'`
    outfiles=`echo $check|awk  '{split($0,a," ");print a[2],a[3],a[4],a[5],a[6],a[7],a[8],a[9],a[10]}'`
#    echo 1fjob $1 $2, to check $cmd $outfiles 
#    echo CMD: $cmd $outfiles
    if test `$cmd $outfiles | wc -l` != 0  > /dev/null 2>&1 ; then
      return 0
    else
    #echo no existe trabajo correcto de $1
      return 1
    fi
  else
    cmd=`echo $check |awk  '{split($0,a," ");print a[1]}'`
    outfiles=`echo $check|awk  '{split($0,a," ");print a[2],a[3],a[4],a[5],a[6],a[7],a[8],a[9],a[10]}'`
#    echo 12job $1 $2, to check $cmd $outfiles 
#    echo CMD: $cmd $outfiles
    if eval $cmd $outfiles > /dev/null 2>&1 ; then
      return 0
    else
    #echo no existe trabajo correcto de $1
      return 1
    fi
  fi
 fi
}

