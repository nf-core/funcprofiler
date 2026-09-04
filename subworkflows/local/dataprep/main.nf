//
// Prepare the reads for profiling.
//
// Takes the validated samplesheet channel from PIPELINE_INITIALISATION, merges the sequencing
// runs belonging to the same sample, and emits the two read layouts the profilers need:
//
//   reads        - 1 file for single-end samples, 2 for paired-end, real endedness preserved.
//   reads_concat - always exactly 1 file, R1 and R2 concatenated, `meta.single_end` forced to
//                  true so that single-FASTQ tools see a single-end sample.
//
include { CAT_FASTQ as MERGE_RUNS } from '../../../modules/nf-core/cat/fastq/main'
include { CAT_FASTQ } from '../../../modules/nf-core/cat/fastq/main'

workflow DATAPREP {
    take:
    reads // channel: [ val(meta), [ path(reads) ] ]

    main:

    // Step 1: Group by meta.id and merge runs if needed
    ch_grouped = reads
        .map { meta, fastqs ->
            // Create grouping key and new meta without run_accession for grouping
            def group_key = meta.id
            [group_key, meta, fastqs]
        }
        .groupTuple(by: 0)
        .map { _group_key, meta_list, reads_list ->
            // Take the first meta as template (they should all have same id)
            def meta = meta_list[0]
            // Remove run_accession since we're merging runs
            meta = meta - meta.subMap('run_accession')

            // Flatten all reads into a single list
            def all_reads = reads_list.flatten()

            [meta, all_reads]
        }
        .branch { meta, fastqs ->
            merge: (meta.single_end && fastqs.size() > 1) || (!meta.single_end && fastqs.size() > 2)
            skip: true
        }

    // Merge reads for samples that need it
    ch_merged = MERGE_RUNS(ch_grouped.merge).reads

    // Combine merged and non-merged samples
    ch_reads = ch_merged.mix(ch_grouped.skip)

    // Step 2: Create concatenated single-file version for tools that need it
    ch_for_concat = ch_reads
        .map { meta, fastqs ->
            // Mark as single_end for CAT_FASTQ to concatenate R1 and R2 into one file
            def meta_concat = meta.clone()
            meta_concat.single_end = true
            [meta_concat, fastqs]
        }
        .branch { _meta, fastqs ->
            concat: fastqs.size() > 1
            skip: true
        }

    // Concatenate all reads into single file per sample
    ch_concatenated = CAT_FASTQ(ch_for_concat.concat).reads
        .mix(ch_for_concat.skip)
        .map { meta, fastqs ->
            // Ensure reads is always a list
            [meta, [fastqs].flatten()]
        }

    emit:
    reads = ch_reads // Paired-end reads (R1, R2) or single-end
    reads_concat = ch_concatenated // All reads concatenated into single file
}
