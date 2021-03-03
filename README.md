# k-mer_mining_SRA

The script reads a list of SRA run accessions. Each run is downloaded and compared to a reference sequence using exact-match 31-mers with bbduk.
The number of reads matching the reference is recorded in the file 'output.txt'. Additionaly, each accession that is processed has its number added to the output.txt
file with a '@' prepended to it. This keeps track of the records that did not return any matches. Any accessions that can not be downloaded have their numbers
added to the 'missing.txt' file. After processing each accession, the fastq files are removed before attempting to download the next accession.
When the script reaches the end of the accession list, it begins processing the missing.txt list. The script will continue to run until all accessions are processed.
