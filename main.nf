#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/funcprofiler
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/funcprofiler
    Website: https://nf-co.re/funcprofiler
    Slack  : https://nfcore.slack.com/channels/funcprofiler
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FUNCPROFILER } from './workflows/funcprofiler'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_funcprofiler_pipeline'
include { PIPELINE_COMPLETION } from './subworkflows/local/utils_nfcore_funcprofiler_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NFCORE_FUNCPROFILER {
    take:
    samplesheet // channel: samplesheet read in from --input
    databases // channel: databases in from --databases

    main:

    //
    // WORKFLOW: Run pipeline
    //
    FUNCPROFILER (
        samplesheet,
        databases,
        params.multiqc_config,
        params.multiqc_logo,
        params.multiqc_methods_description,
        params.outdir,
    )

    emit:
    multiqc_report = FUNCPROFILER.out.multiqc_report // channel: /path/to/multiqc_report.html
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION(
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input,
        params.databases,
        params.help,
        params.help_full,
        params.show_hidden,
    )

    def profileUsesContainers = (workflow.containerEngine != null && workflow.containerEngine != '')

    // if (params.run_fmhfunprofiler) {
    //     if (!profileUsesContainers) {
    //         error(
    //             """\
    //         ---------------------------------------------------------------
    //         ERROR: The step "fmhfunprofiler" currently requires that it be
    //         run with a profile with containerized support.  We are working
    //         to add this tool to bioconda and add non-containerized profile
    //         support shortly.

    //         Either:
    //           1. Rerun this pipeline using a container-enabled profile eg:
    //           `-profile singularity`.
    //           2. Disable this step by omitting the `run_fmhfunprofiler`
    //           flag.
    //         """
    //         )
    //     }
    // }

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_FUNCPROFILER(
        PIPELINE_INITIALISATION.out.samplesheet,
        PIPELINE_INITIALISATION.out.databases,
    )
    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION(
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
        NFCORE_FUNCPROFILER.out.multiqc_report,
    )
}
