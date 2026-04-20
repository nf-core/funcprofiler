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
            // Create grouping key and new meta without run_accession for grouping
            def group_key = meta.id
            [group_key, meta, reads]
        }
        .groupTuple(by: 0)  // Group by meta.id
        .map { group_key, meta_list, reads_list ->
            // Take the first meta as template (they should all have same id)
            def meta = meta_list[0]
            // Remove run_accession since we're merging runs
            meta = meta - meta.subMap('run_accession')

            // Flatten all reads into a single list
            def all_reads = reads_list.flatten()

            [meta, all_reads]
        }
        .branch { meta, reads ->
            // Branch based on whether merging is needed
            // For paired-end: need merging if more than 2 files (more than 1 pair)
            // For single-end: need merging if more than 1 file
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
            // Mark as single_end for CAT_FASTQ to concatenate R1 and R2 into one file
            def meta_concat = meta.clone()
            meta_concat.single_end = true
            [meta_concat, reads]
        }
        .branch { meta, reads ->
            // Only need to concatenate if we have multiple files
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
