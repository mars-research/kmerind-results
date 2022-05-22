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

DATA_DIR=~/dataset
LOCALTMP=${ROOTDIR}/tmp
OUT_DIR=${ROOTDIR}/tmp

DATE=`date +%Y%m%d-%H%M%S`
logdir=${ROOTDIR}/data/compbio-gerbil-strongscale-G_gallus
mkdir -p ${LOCALTMP}
mkdir -p ${logdir}/gerbil
mkdir -p ${logdir}/kmc3
mkdir -p ${logdir}/kmerind

mkdir -p $logdir

TIME_CMD="/usr/bin/time -v"
CACHE_CLEAR_CMD="free && sync && echo 3 > /proc/sys/vm/drop_caches && free"
MPIRUN_CMD="mpirun"


/usr/bin/numactl -H

##================= now execute.

#echo "CACHE CLEARING VERSION"
#echo "Nodes:  ORIG ${SLURM_NODELIST}"
#echo "NNodes:  ORIG ${SLURM_NNODES}"
#echo "T/Nodes:  ORIG ${SLURM_TASKS_PER_NODE}"
#echo "NT/Node:  ORIG ${SLURM_NTASKS_PER_NODE}"
#echo "TASKS:  ORIG ${SLURM_NTASKS}"


GERBIL_EXEC=${ROOTDIR}/build/gerbil/gerbil
KMERIND_BIN_DIR=./build/bin
KMC_EXEC=${ROOTDIR}/build/kmc3/kmc


## ================= dataset.

dataset=SRR077487.2
#dataset=SRR072006
datafile=${DATA_DIR}/${dataset}.fastq


#unset any OMP or numa stuff.
unset OMP_PROC_BIND
unset GOMP_CPU_AFFINITY
unset OMP_PLACES
unset OMP_NUM_THREADS


#=========== kmerind


#drop cache
#eval "sudo /usr/local/crashplan/bin/CrashPlanEngine stop"
#eval "/usr/local/sbin/drop_caches"

#warm up
EXEC=${KMERIND_BIN_DIR}/testKmerCounter-FASTQ-a4-k31-CANONICAL-DENSEHASH-COUNT-dtIDEN-dhFARM-shFARM
echo "$MPIRUN_CMD --use-hwthread-cpus -np 64 --map-by ppr:32:socket --rank-by core --bind-to core $EXEC -O ${LOCALTMP}/test.out ${datafile}" > ${logdir}/kmerind_uncached.log
eval "$MPIRUN_CMD --use-hwthread-cpus -np 64 --map-by ppr:32:socket --rank-by core --bind-to core $EXEC -O ${LOCALTMP}/test.out ${datafile} >> ${logdir}/kmerind_uncached.log 2>&1"

rm -f ${LOCALTMP}/test.out*




for t in 64 32 16 8
do

  cpu_node_cores=$((t / 2))

  for iter in 1 2 3
  do


    for K in 63 31 21 15
    do


      for map in RADIXSORT BROBINHOOD
      do

        hash=MURMUR64avx


        # kmerind
        for EXEC in ${KMERIND_BIN_DIR}/testKmerCounter-FASTQ-a4-k${K}-CANONICAL-${map}-COUNT-dtIDEN-dh${hash}-shCRC32C
        do 

          exec_name=$(basename ${EXEC})

          logfile=${logdir}/kmerind/${exec_name}-n1-p${t}-${dataset}.$iter.log
          outfile=${OUT_DIR}/${exec_name}-n1-p${t}-${dataset}.$iter.bin

          # only execute if the file does not exist.
          if [ ! -f $logfile ] || [ "$(tail -1 $logfile)" != "COMPLETED" ]
          then
          
            # command to execute
            cmd="$MPIRUN_CMD --use-hwthread-cpus -np ${t} --map-by ppr:${cpu_node_cores}:socket --rank-by core --bind-to core $EXEC -O $outfile -B 6 ${datafile}"
            echo "COMMAND" > $logfile
            echo $cmd >> $logfile
            echo "COMMAND: ${cmd}" 
            echo "LOGFILE: ${logfile}"
                  
            # call the executable and save the results
            echo "RESULTS" >> $logfile
            eval "($TIME_CMD $cmd >> $logfile 2>&1) >> $logfile 2>&1"
          
            echo "COMPLETED" >> $logfile
            echo "$exec_name COMPLETED."
            rm ${outfile}*
            
          else
          
            echo "$logfile exists and COMPLETED.  skipping."
          fi

        done
        #EXEC


      done
      #map



      #================ Densehash (Kmerind)
      map=DENSEHASH
      hash=FARM

      # kmerind
      for EXEC in ${KMERIND_BIN_DIR}/testKmerCounter-FASTQ-a4-k${K}-CANONICAL-${map}-COUNT-dtIDEN-dh${hash}-sh${hash}
      do 

        exec_name=$(basename ${EXEC})

        logfile=${logdir}/kmerind/${exec_name}-n1-p${t}-${dataset}.$iter.log
        outfile=${OUT_DIR}/${exec_name}-n1-p${t}-${dataset}.$iter.bin

        # only execute if the file does not exist.
        if [ ! -f $logfile ] || [ "$(tail -1 $logfile)" != "COMPLETED" ]
        then
          
          # command to execute
          cmd="$MPIRUN_CMD -np ${t} --map-by ppr:${cpu_node_cores}:socket --rank-by core --bind-to core $EXEC -O $outfile -B 6 ${datafile}"
          echo "COMMAND" > $logfile
          echo $cmd >> $logfile
          echo "COMMAND: ${cmd}" 
          echo "LOGFILE: ${logfile}"
                
          # call the executable and save the results
          echo "RESULTS" >> $logfile
          eval "($TIME_CMD $cmd >> $logfile 2>&1) >> $logfile 2>&1"
        
          echo "COMPLETED" >> $logfile
          echo "$exec_name COMPLETED."
          rm ${outfile}*
            
        else
        
          echo "$logfile exists and COMPLETED.  skipping."
        fi

      done
      #EXEC


    done
    #K

  done
  #iter


done
#t
