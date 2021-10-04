
APS  created in 2016 by Rafael Larrosa Jiménez (rlarrosa@uma.es)

This project is used for the creation of pipelines of jobs, with complex
dependencies.  It allows the sending of multiple jobs to a queue system in an
easy way.  

Jobs can be composed of multiple programs and multiple input files.

The input files must be defined in a file that contains the samples that are
going to be processed.  The name of this file should be defined in the
environment variable INPUTFILE, if not defined by default it is
lista_exomas_completa.txt.

Inside this file are the name of the samples, ordered by columns, for example:


AIS             INV             NORMAL

RRS1024983      RRS1024984      RRS1024985

RRS1024986      RRS1024987      RRS1024988

RRS1024989      RRS1024990      RRS1024991



The programs that are going to be applied must be inside the subdirectory
scritps_to_send, all the ones that begin between 1 and 9 will be send to the
queue system, with dependencies, from the 2 to the 9, to the previous number.

A directory will be created for each input, and inside the scripts the word
SAMPLE will be substituted by the name of the sample.


Also some jobs can process several samples, those are recognized by the use of 
the word in the env var PROCESS_LINE inside the name of the script,
by default compare.


