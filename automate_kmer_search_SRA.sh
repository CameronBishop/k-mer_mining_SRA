#!/bin/bash

# usage: script.sh list_of_Accessions.txt reference.fasta threads<int>

# the script reads a list of SRA accessions. Each run is downloaded and compared to a reference sequence.
# The number of reads matching the reference is recorded in the file 'output.txt'. Additionaly, each accession that is processed has its number added to the output.txt
# file with a '@' prepended to it. This keeps track of the records that did not return any matches. Any accessions that can not be downloaded have their numbers
# added to the 'missing.txt' file. After processing each accession, the fastq files are removed before attempting to download the next accession.
# When the script reaches the end of the accession list, it begins processing the missing.txt list. The script will continue to run until all accessions are processed.


if [[ -n $1 && -n $2 && -n $3 ]]; then
 
    # copy the accession list to tempfiles directory and give it a generic name.
    n=1; 
    if [[ ! -d "tempfiles" ]]; then mkdir tempfiles; fi
    acc="tempfiles/acc_list_"$n".txt"; cat $1 > $acc
    
    # set up the output files
    touch output.txt
    echo -e 'Acc' '\t' 'Ref' '\t' 'matches' '\t' 'percent' >> output.txt
    miss="tempfiles/missing.txt" && touch $miss


    # if its the first iteration of the loop, or if missing files exist: continue
    while [[ $n -eq 1 || $lenacc > 0 ]]; do

        last=$(tail -1 $acc)

        input=$acc
        while IFS= read -r line  || [ -n "$line" ]; do

            # try to download the next accession in the list, and convert to fastq file     
            echo ""; echo "######################## attempting fasterq-dump on "$line; echo ""
            current=$line
            skip=0
            fasterq-dump -t /dev/shm -e $3 --split-spot -m 500MB --bufsize 500MB $line; fqdx=$?
            
            # if a record is found, perform the kmer search. Otherwise skip to the next accession
            if [[ $fqdx -eq 0 && -f $(echo $line*fastq) ]]; then 
                echo ""; echo "######################## fasterq-dump succeeded on "$line; echo ""  
                cat $line*fastq | bbduk.sh int=f -Xmx2g in=stdin.fq ref=$2 k=31 stats=stats.txt; bbdx=$? 
                rm -rf $line 
            elif [[ $fqdx -ne 0 || ! -f $(echo $line*fastq) ]]; then 
                # if not found, add the accession to a list of missing datasets, and skip to the next accession
                echo ""; echo "######################## fasterq-dump failed on "$line; echo ""
                echo $line >> $miss
                if [ ! -z "$(ls -A /dev/shm)" ]; then rm -r /dev/shm/* ; fi
                if [ -f $(echo $line*fastq) ]; then rm  $line*fastq ; fi
                skip=1  
                sleep 2
            fi

            # if bbduk succeeded, add results of bbduk to an output file, otherwise stop the script
            if [[ $bbdx -eq 0 && $skip -eq 0 ]]; then
                echo ""; echo "######################## writing data for "$line; echo ""
                echo "@"$line >> output.txt
                grep -v '^#' stats.txt  | sed -e "s/^/$line\t/" >> output.txt; rm stats.txt && \
                echo ""; echo "######################## finished processing "$line; echo ""
                rm $line*fastq
            elif [[ $bbdx -ne 0 && $skip -eq 0 ]]; then 
                echo ""; echo "######################## bbduk failed on "$line; echo ""
                rm $line*fastq
                break 4
            fi      

        done < $acc

        if [[ "$current" == "$last" ]]; then 
            ((n++)) 
            rm $acc                                                 
            acc="tempfiles/acc_list_"$n".txt"                       
            mv $miss $acc && touch $miss
            lenacc=$(wc -l "$acc" | cut -f1 -d ' ') 
        else
            echo ""; echo "######################## A problem occurred before finished processing accessions in "$acc; echo ""
            break 3
        fi
   
    done 


    if [[ $lenacc -eq 0 ]]; then
    echo ""; echo "######################## Job finished"; echo ""
    fi 


else
  echo "An argument is missing"
fi