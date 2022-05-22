#!/bin/bash
#----------------------------------------------------
# Example SLURM job script to run hybrid applications 
# (MPI/OpenMP or MPI/pthreads) on TACC's Stampede 
# system.
#----------------------------------------------------
#SBATCH -J strongscale_G     # Job name
##SBATCH -p normal    # Queue name

## OVERRIDE THESE ON COMMANDLINE.
#SBATCH -N 1               # Total number of nodes requested (16 cores/node)
#SBATCH -n 72              # Total number of mpi tasks requested

#SBATCH -t 48:00:00       # Run time (hh:mm:ss) - 1.5 hours
# The next line is required if the user has more than one project
# #SBATCH -A A-yourproject  # <-- Allocation name to charge job against

# Set the number of threads per task(Default=1)

ROOTDIR=./out/

DATA_DIR=~/kmerind/dataset
LOCALTMP=${ROOTDIR}/tmp
OUT_DIR=${ROOTDIR}/tmp

DATE=`date +%Y%m%d-%H%M%S`
logdir=${ROOTDIR}/log
mkdir -p ${logdir}/kmerind

TIME_CMD="/usr/bin/time -v"
CACHE_CLEAR_CMD="free && sync && echo 3 > /proc/sys/vm/drop_caches && free"
MPIRUN_CMD="mpirun"


/usr/bin/numactl -H

##================= now execute.

echo "CACHE CLEARING VERSION"
echo "Nodes:  ORIG ${SLURM_NODELIST}"
echo "NNodes:  ORIG ${SLURM_NNODES}"
echo "T/Nodes:  ORIG ${SLURM_TASKS_PER_NODE}"
echo "NT/Node:  ORIG ${SLURM_NTASKS_PER_NODE}"
echo "TASKS:  ORIG ${SLURM_NTASKS}"


KMERIND_BIN_DIR=./build/bin


## ================= dataset.

dataset=SRR072006
datafile=${DATA_DIR}/${dataset}.fastq


#unset any OMP or numa stuff.
unset OMP_PROC_BIND
unset GOMP_CPU_AFFINITY
unset OMP_PLACES
unset OMP_NUM_THREADS


#=========== kmerind

#set -euo pipefail

#drop cache
#eval "sudo /usr/local/crashplan/bin/CrashPlanEngine stop"
#eval "/usr/local/sbin/drop_caches"

#warm up
#EXEC=${KMERIND_BIN_DIR}/testKmerIndex-FASTQ-a4-k31-SINGLE-DENSEHASH-COUNT-dtIDEN-dhFARM-shFARM
EXEC=${KMERIND_BIN_DIR}/testKmerIndex-FASTQ-a4-k31-CANONICAL-DENSEHASH-COUNT-dtIDEN-dhFARM-shFARM
echo "$MPIRUN_CMD --use-hwthread-cpus -np 64 --map-by ppr:32:socket --rank-by core --bind-to core $EXEC -F ${datafile}" > ${logdir}/kmerind_uncached.log
eval "$MPIRUN_CMD --use-hwthread-cpus -np 64 --map-by ppr:32:socket --rank-by core --bind-to core $EXEC -F ${datafile} >> ${logdir}/kmerind_uncached.log 2>&1"

rm -f ${LOCALTMP}/test.out*

NUM_SOCKETS=$(grep physical.id /proc/cpuinfo | sort -u | wc -l)

echo "number of sockets " $NUM_SOCKETS

disttrans=IDEN
# FARM is the fastest hash per fig 7
disthash=FARM
storehash=FARM

for t in 64
do

  cpu_node_cores=$((t / $NUM_SOCKETS))

  for iter in 1 2 3
  do


    for K in 63 31 21 15
    do


      for map in DENSEHASH
      do
        


        # kmerind
        #for EXEC in ${KMERIND_BIN_DIR}/testKmerIndex-FASTQ-a4-k${K}-SINGLE-${map}-COUNT-dt${disttrans}-dh${storehash}-sh${storehash}

	# kmerhash
        for EXEC in ${KMERIND_BIN_DIR}/testKmerIndex-FASTQ-a4-k${K}-CANONICAL-${map}-COUNT-dt${disttrans}-dh${storehash}-sh${storehash}
        do 

          exec_name=$(basename ${EXEC})

          logfile=${logdir}/kmerind/${exec_name}-n1-p${t}-${dataset}.$iter.log

          # only execute if the file does not exist.
          if [ ! -f $logfile ] || [ "$(tail -1 $logfile)" != "COMPLETED" ]
          then
          
            # command to execute
            cmd="$MPIRUN_CMD --use-hwthread-cpus -np ${t} --map-by ppr:${cpu_node_cores}:socket --rank-by core --bind-to core $EXEC -F ${datafile}"
            echo "COMMAND" > $logfile
            echo $cmd >> $logfile
            echo "COMMAND: ${cmd}" 
            echo "LOGFILE: ${logfile}"
                  
            # call the executable and save the results
            echo "RESULTS" >> $logfile
            eval "($TIME_CMD $cmd >> $logfile 2>&1) >> $logfile 2>&1"
          
            echo "COMPLETED" >> $logfile
            echo "$exec_name COMPLETED."
            
          else
          
            echo "$logfile exists and COMPLETED.  skipping."
          fi

        done
        #EXEC


      done
      #map


    done
    #K

  done
  #iter


done
#t




