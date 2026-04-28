/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
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
include { UNTAR                         } from '../modules/nf-core/untar/main'
include { CAT_FASTQ as MERGE_RUNS       } from '../modules/nf-core/cat/fastq/main'
include { CONCAT_ALL                    } from '../subworkflows/local/concatall'
include { PROFILING                     } from '../subworkflows/local/profile/main'
include { DATAPREP                      } from '../subworkflows/local/dataprep/main'
include { DBPREP                        } from '../subworkflows/local/dbprep/main'



workflow FUNCPROFILER {

    take:
    samplesheet // channel: samplesheet read in from --input
    databases // channel: databases from --databases

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()



    DATAPREP (
	samplesheet
    )

    DBPREP (
	databases
    )
    PROFILING (
	DATAPREP.out.reads,
	DATAPREP.out.reads_concat,
	DBPREP.out.dbs
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

    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
