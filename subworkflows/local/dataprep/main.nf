include { UNTAR                         } from '../../../modules/nf-core/untar/main'
include { CAT_FASTQ as MERGE_RUNS       } from '../../../modules/nf-core/cat/fastq/main'
include { CAT_FASTQ                     } from '../../../modules/nf-core/cat/fastq/main'


workflow DATAPREP {

    take:
    samplesheet  // [meta, run_accession, instrument_platform, fastq_1, fastq_2, fasta]

    main:

    // Step 1: Validate inputs and set meta fields
    ch_validated = samplesheet
        .map { meta, run_accession, instrument_platform, fastq_1, fastq_2, fasta ->

            // Error checks
            if (instrument_platform == "OXFORD_NANOPORE") {
                error("ERROR: Long read data is not supported!")
            }
            if (fasta) {
                error("ERROR: inputs must be in fastq format, not fasta!")
            }
            if (!fastq_1) {
                error("ERROR: Please check input samplesheet: entry `fastq_1` doesn't exist!")
            }

            // Set single_end based on presence of fastq_2
            meta.single_end = !fastq_2

            // Store additional metadata
            meta.run_accession = run_accession
            meta.instrument_platform = instrument_platform

            // Return tuple of meta and reads
            def reads = fastq_2 ? [fastq_1, fastq_2] : [fastq_1]
            return [meta, reads]
        }

    // Step 2: Group by meta.id and merge runs if needed
    ch_grouped = ch_validated
        .map { meta, reads ->
            def group_key = meta.id
            [group_key, meta, reads]
        }
        .groupTuple(by: 0)
        .map { group_key, meta_list, reads_list ->
            def sorted_pairs = [meta_list, reads_list]
                .transpose()
                .sort { it[0].run_accession }

            def meta = sorted_pairs[0][0]
            meta = meta - meta.subMap('run_accession')
            def all_reads = sorted_pairs.collect { it[1] }.flatten()

            [meta, all_reads]
        }
        .branch { meta, reads ->
            merge: (meta.single_end && reads.size() > 1) || (!meta.single_end && reads.size() > 2)
                return [meta, reads]
            skip: true
                return [meta, reads]
        }

    // Merge reads for samples that need it
    ch_merged = MERGE_RUNS(ch_grouped.merge).reads

    // Combine merged and non-merged samples
    ch_reads = ch_merged.mix(ch_grouped.skip)

    // Step 3: Create concatenated single-file version for tools that need it
    ch_for_concat = ch_reads
        .map { meta, reads ->
            def meta_concat = meta.clone()
            meta_concat.single_end = true
            def sorted_reads = reads.sort { it.name }
            [meta_concat, sorted_reads]
        }
        .branch { meta, reads ->
            concat: reads.size() > 1
                return [meta, reads]
            skip: true
                return [meta, reads]
        }

    // Concatenate all reads into single file per sample
    ch_concatenated = CAT_FASTQ(ch_for_concat.concat).reads
        .mix(ch_for_concat.skip)
        .map { meta, reads ->
            // Ensure reads is always a list
            [meta, [reads].flatten()]
        }

    emit:
    reads = ch_reads              // Paired-end reads (R1, R2) or single-end
    reads_concat = ch_concatenated  // All reads concatenated into single file
}
