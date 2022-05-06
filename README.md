# Kmerind Results

## List of updated scripts

* *run/fig4/benchmark_multithread_vary_k.sh*

## Modifications

Some modifications to the original scripts were made to make sure that it can run the new kmerind repo on our hardware(c220g2 on Cloudlab):

* Map by socket: the original scripts use `--map-by ppr:${cpu_node_cores}:socket`, where `cpu_node_cores=$((num_threads / 4))`. I think that `4` means the number of sockets on their systems. 

## Original README

This repository is the companion to the "kmerhash" repository, and contains supporting information for the SC18 paper titled "Optimizing High Performance Distributed Memory Parallel Hash Tables with Application to DNA $k$-mer Counting".

The "excel" directory contains all Microsoft Excel files that are used to generate the figures and tables in the results section of the paper.  They also contain extracts from the experimental logs.  The filenames are prefixed with the figure or tables number.  Please note that the figures are under IEEE copyright.

The "scripts" directory contains the SLURM job scripts used for the experiments.   These serve as references and templates for building your own script that uses the binaries from the "kmerhash" project.  The scripts are arranged in directories corresponding to the figure and table numbers in the paper.

This work, with the exception of the figures in the Excel files that appears in the SC18 paper, is licensed under a Creative Commons Attribution 4.0 License.  The full license can be found here: http://creativecommons.org/licenses/by/4.0/legalcode.
