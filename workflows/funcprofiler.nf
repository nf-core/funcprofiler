/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTQC                 } from '../modules/nf-core/fastqc/main'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_funcprofiler_pipeline'

// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.databases,
//                            params.longread_hostremoval_index,
//                            params.hostremoval_reference, params.shortread_hostremoval_index,
//                            params.multiqc_config, params.shortread_qc_adapterlist,
//                            params.krona_taxonomy_directory,
//                            params.taxpasta_taxonomy_dir,
//                            params.multiqc_logo, params.multiqc_methods_description
                        ]
checkPathParamList.each{param ->
    if (param) { file(param, checkIfExists: true) }
}

// Check mandatory parameters (stolen from taxprofiler
if ( params.input ) {
    ch_input              = file(params.input, checkIfExists: true)
} else {
    error("Input samplesheet not specified")
}

if (params.databases) { ch_databases = file(params.databases, checkIfExists: true) } else { error('Input database sheet not specified!') }


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/




//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { UNTAR                       } from '../modules/nf-core/untar/main'
include { CAT_FASTQ as MERGE_RUNS     } from '../modules/nf-core/cat/fastq/main'

include { CONCAT_ALL                    } from '../subworkflows/local/concatall'
include { PROFILING                     } from '../subworkflows/local/profiling'



workflow FUNCPROFILER {

    take:
    samplesheet // channel: samplesheet read in from --input
    databases // channel: databases from --databases

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

   // Validate input files and create separate channels for FASTQ, FASTA, and Nanopore data
    ch_input = samplesheet
        .map { meta, run_accession, instrument_platform, fastq_1, fastq_2, fasta ->
            meta.run_accession = run_accession
            meta.instrument_platform = instrument_platform

            // Define single_end based on the conditions
            meta.single_end = ( fastq_1 && !fastq_2 && instrument_platform != 'OXFORD_NANOPORE' )

            // Define is_fasta based on the presence of fasta
            meta.is_fasta = fasta ? true : false

            if ( !meta.is_fasta && !fastq_1 ) {
                error("ERROR: Please check input samplesheet: entry `fastq_1` doesn't exist!")
            }
            if ( meta.instrument_platform == 'OXFORD_NANOPORE' && fastq_2 ) {
                error("Error: Please check input samplesheet: for Oxford Nanopore reads entry `fastq_2` should be empty!")
            }
            if ( meta.single_end && fastq_2 ) {
                error("Error: Please check input samplesheet: for single-end reads entry `fastq_2` should be empty")
            }
            return [ meta, run_accession, instrument_platform, fastq_1, fastq_2, fasta ]
        }
        .branch { meta, run_accession, instrument_platform, fastq_1, fastq_2, fasta ->
            fastq: meta.single_end || fastq_2
                return [ meta + [ type: "short" ], fastq_2 ? [ fastq_1, fastq_2 ] : [ fastq_1 ] ]
            nanopore: instrument_platform == 'OXFORD_NANOPORE' && !meta.is_fasta
                meta.single_end = true
                return [ meta + [ type: "long" ], [ fastq_1 ] ]
            fasta_short: meta.is_fasta && instrument_platform == 'ILLUMINA'
                meta.single_end = true
                return [ meta + [ type: "short" ], [ fasta ] ]
            fasta_long: meta.is_fasta && instrument_platform == 'OXFORD_NANOPORE'
                meta.single_end = true
                return [ meta + [ type: "long" ], [ fasta ] ]
        }

    // Merge ch_input.fastq and ch_input.nanopore into a single channel
    ch_input_for_fastqc = ch_input.fastq.mix( ch_input.nanopore )

    // Validate and decompress databases
    ch_dbs_for_untar = databases
        .branch { db_meta, db_path ->
            if ( !db_meta.db_type ) {
                db_meta = db_meta + [ db_type: "short;long" ]
            }
            untar: db_path.name.endsWith( ".tar.gz" )
            skip: true
        }
    // Filter the channel to untar only those databases for tools that are selected to be run by the user.
    // Also, to ensure only untar once per file, group together all databases of one file
    ch_inputdb_untar = ch_dbs_for_untar.untar
        .filter { db_meta, db_path ->
            params[ "run_${db_meta.tool}" ]
        }
        .groupTuple(by: 1)
        .map {
            meta, dbfile ->
                def new_meta = [ 'id': dbfile.baseName ] + [ 'meta': meta ]
            [new_meta , dbfile ]
        }

    // Untar the databases
    UNTAR ( ch_inputdb_untar )
    // Spread out the untarred and shared databases
    ch_outputdb_from_untar = UNTAR.out.untar
        .map {
            meta, db ->
            [meta.meta, db]
        }
        .transpose(by: 0)

    ch_semifinal_dbs = ch_dbs_for_untar.skip
                    .mix( ch_outputdb_from_untar  )
                    .map { db_meta, db ->
                        def corrected_db_params = db_meta.db_params ? [ db_params: db_meta.db_params ] : [ db_params: '' ]
                        [ db_meta + corrected_db_params, db ]
        }
//    println(ch_semifinal_dbs.view())
    ch_grouped_dbs = ch_semifinal_dbs
	.map { meta, path ->
	    [ [tool: meta.tool, db_name: meta.db_name], [meta.db_entity, meta.db_params, meta.db_type, path]]
	}
	.groupTuple()
	.map { groupKey, groupTuples ->
            def grouped_dbs = groupTuples.collect { t ->
		def (db_entity, db_params, db_type, path) = t
		[db_entity: db_entity, db_params: db_params, db_type: db_type, db_path:path]
            }
            [groupKey,  grouped_dbs]
	}



    //TODO: preprocess subworkflow
    /*
        SUBWORKFLOW: PERFORM PREPROCESSING
    */

    if ( params.perform_shortread_qc ) {
        ch_shortreads_preprocessed = SHORTREAD_PREPROCESSING ( ch_input.fastq, adapterlist ).reads
        ch_versions = ch_versions.mix( SHORTREAD_PREPROCESSING.out.versions )
    } else {
        ch_shortreads_preprocessed = ch_input.fastq
    }
    ch_longreads_preprocessed = Channel.empty()
    if ( params.perform_runmerging || true ) {

        ch_reads_for_cat_branch = ch_shortreads_preprocessed
            .mix( ch_longreads_preprocessed )
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

        ch_reads_runmerged = MERGE_RUNS ( ch_reads_for_cat_branch.cat ).reads
            .mix( ch_reads_for_cat_branch.skip )
            .map {
                meta, reads ->
                [ meta, [ reads ].flatten() ]
            }
            .mix( ch_input.fasta_short, ch_input.fasta_long)

        //ch_versions = ch_versions.mix(MERGE_RUNS.out.versions)

    } else {
        ch_reads_runmerged = ch_shortreads_preprocessed
            .mix( ch_longreads_preprocessed, ch_input.fasta_short, ch_input.fasta_long )
    }



    PROFILING (
	ch_reads_runmerged,
	ch_grouped_dbs,
    )

   softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'funcprofiler_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    def summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )



    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)

    // def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    // def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    // ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))

    // def ch_multiqc_custom_methods_description = multiqc_methods_description
    //     ? file(multiqc_methods_description, checkIfExists: true)
    //     : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    // def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    // ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))

    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'funcprofiler'],
                files,
                params.multiqc_config
                    ? file(params.multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                params.multiqc_logo ? file(params.multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )

    emit:
    multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html

//    emit:multiqc_report = Channel.empty()  // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
