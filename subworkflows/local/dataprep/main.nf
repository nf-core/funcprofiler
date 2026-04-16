include { UNTAR                         } from '../../../modules/nf-core/untar/main'
include { CAT_FASTQ as MERGE_RUNS       } from '../../../modules/nf-core/cat/fastq/main'
include { CAT_FASTQ                     } from '../../../modules/nf-core/cat/fastq/main'

workflow DATAPREP {

    take:
    samplesheet

    main:

    ch_input = samplesheet
        .map { meta, run_accession, instrument_platform, fastq_1, fastq_2, fasta ->
            meta.run_accession = run_accession
            meta.instrument_platform = instrument_platform

            // Define is_fasta based on the presence of fasta
            meta.is_fasta = fasta ? true : false

	    if ( meta.is_fasta ) {
                error("ERROR: inputs must be in fastq format, not fasta!")
            }
	    if ( instrument_platform == "OXFORD_NANOPORE" ) {
                error("ERROR: Long read data is not supported!")
            }
            // Define single_end based on the conditions
            meta.single_end = ( fastq_1 && !fastq_2 && instrument_platform != 'OXFORD_NANOPORE' )


            if ( !meta.is_fasta && !fastq_1 ) {
                error("ERROR: Please check input samplesheet: entry `fastq_1` doesn't exist!")
            }
            if ( meta.single_end && fastq_2 ) {
                error("Error: Please check input samplesheet: for single-end reads entry `fastq_2` should be empty")
            }
            return [ meta, run_accession, instrument_platform, fastq_1, fastq_2, fasta ]
        }
        .branch { meta, run_accession, instrument_platform, fastq_1, fastq_2, fasta ->
            fastq: meta.single_end || fastq_2
                return [ meta + [ type: "short" ], fastq_2 ? [ fastq_1, fastq_2 ] : [ fastq_1 ] ]
            other: true
                return [ meta + [ type: "invalud" ], [ ] ]
        }


    ch_shortreads_preprocessed = ch_input.fastq

    if ( params.perform_runmerging || true ) {

        ch_reads_for_cat_branch = ch_shortreads_preprocessed
            .map {
                meta, reads ->
                    def meta_new = meta - meta.subMap('run_accession')
                [ meta_new, reads ]
            }
            .groupTuple()
            .map {
                meta, reads ->
                    [ meta, reads.flatten() ]
            }
            .branch {
                meta, reads ->
                // we can't concatenate files if there is not a second run, we branch
                // here to separate them out, and mix back in after for efficiency
                cat: ( meta.single_end && reads.size() > 1 ) || ( !meta.single_end && reads.size() > 2 )
                skip: true
            }
	// Process the cat branch
	tmp_ch_reads_runmerged = MERGE_RUNS ( ch_reads_for_cat_branch.cat ).reads

        ch_reads_runmerged = tmp_ch_reads_runmerged
            .mix( ch_reads_for_cat_branch.skip )
            .map {
                meta, reads ->
                [ meta, [ reads ].flatten() ]
            }


    } else {
        ch_reads_runmerged = ch_shortreads_preprocessed
    }


    /////////////// Prepare the concatenate files for tools that accept a single fastq file
    ch_input_pre_concat = ch_reads_runmerged
	.map {
            meta, reads ->
            def meta_new = meta - meta.subMap('run_accession')
	    meta_new["single_end"] = true // call them "single end" so CAT_FASTQ actually flattens R1 and R2 into single file
            [ meta_new, reads ]
        }
        .groupTuple()
        .map {
            meta, reads  ->
            [ meta, reads.flatten() ]
        }
        .branch {
            _meta, reads  ->
                // we can't concatenate files if there is not a second run, we branch
                // here to separate them out, and mix back in after for efficiency
                cat: reads.size() > 1
                skip: true
            }

    ch_input_concat = CAT_FASTQ ( ch_input_pre_concat.cat ).reads
	.map { meta, reads -> [ meta, [reads].flatten() ] }
	.mix( ch_input_pre_concat.skip )


    emit:
    // TODO nf-core: edit emitted channels
    reads         = ch_reads_runmerged
    reads_concat  = ch_input_concat
}
