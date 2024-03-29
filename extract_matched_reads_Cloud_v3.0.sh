#!/bin/bash

# usage: script.sh   list_of_Accessions.txt   reference.fasta   threads<int>

# notes: Quality scores are ignored. Files containing no quality scores are not processed, and added to 'done.txt' with flag 'failed. no quality scores.' 



if [[ -n $1 && -n $2 && -n $3 ]]; then
 
    # copy the accession list to tempfiles directory and give it a generic name.
    n=1; 
    if [[ ! -d "tempfiles" ]]; then mkdir tempfiles; fi
    acc="tempfiles/acc_list_"$n".txt"; cat $1 > $acc
    
    # set up the output files
    touch done.txt
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
            fasterq-dump --progress -e $3 -m 1000MB --bufsize 1000MB $line; fqdx=$?
            
            # if a record is found, perform the kmer search. Otherwise skip to the next accession
            if [[ $fqdx -eq 0 && -f $(echo $line"_1.fastq") && -f $(echo $line"_2.fastq") ]]; then 
                echo ""; echo "######################## fasterq-dump succeeded on "$line
                echo "######################## "$line" is paired data. Performing re-pair"; echo ""  

                repair.sh -Xmx8g in1=$line"_1.fastq" in2=$line"_2.fastq" out1=clean_reads_1.fastq out2=clean_reads_2.fastq outsingle=singletons && \
                bbduk.sh -Xmx8g ignorebadquality=t in1=clean_reads_1.fastq in2=clean_reads_2.fastq outm=$line'_matched_pairs.fastq' ref=$2 k=25 && \
                gzip $line'_matched_pairs.fastq' && \
                echo ""; echo "######################## finished processing "$line
                echo $line >> done.txt
                rm $line"_1.fastq" $line"_2.fastq" clean_reads*fastq singletons
                
                # sometimes an SRA contains reads without quality scores (reads 0-length). Remove 0-length read file if one exists
                if [[ -f $line".fastq" ]]; then rm $line".fastq"; echo $line" failed. no quality scores." >> done.txt; fi

            elif [[ $fqdx -eq 0 && -f $(echo $line".fastq") ]]; then 
                echo ""; echo "######################## fasterq-dump succeeded on "$line; echo ""
                echo "######################## "$line" is single-end data. Skipping re-pair"; echo ""  

                cat $line*fastq | bbduk.sh -Xmx2g ignorebadquality=t int=f in=stdin.fq outm=$line'_matched_reads.fastq' ref=$2 k=25 && \
                gzip $line'_matched_reads.fastq'; bbdx=$? 
                echo ""; echo "######################## finished processing "$line
                echo $line >> done.txt
                rm -rf $line".fastq" 
            
            elif [[ $fqdx -ne 0 || ! -f $(echo $line"*fastq") ]]; then 
                # if not found, add the accession to a list of missing datasets, and skip to the next accession
                echo ""; echo "######################## fasterq-dump failed on "$line; echo ""
                echo $line >> $miss
                if [ ! -z "$(ls -A /dev/shm)" ]; then rm -r /dev/shm/* ; fi
                if [ -f $(echo $line*fastq) ]; then rm  $line*fastq ; fi
                skip=1  
                sleep 2
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
