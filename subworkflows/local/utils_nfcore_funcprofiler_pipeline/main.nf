//
// Subworkflow with functionality specific to the nf-core/funcprofiler pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN } from '../../nf-core/utils_nfschema_plugin'
include { paramsSummaryMap } from 'plugin/nf-schema'
include { samplesheetToList } from 'plugin/nf-schema'
include { completionEmail } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NEXTFLOW_PIPELINE } from '../../nf-core/utils_nextflow_pipeline'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {
    take:
    version // boolean: Display version and exit
    validate_params // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir //  string: The output directory where the results will be saved
    input //  string: Path to input samplesheet
    databases //  string: Path to databases
    help // boolean: Display help message and exit
    help_full // boolean: Show the full help message
    show_hidden // boolean: Show hidden parameters in the help message

    main:

    ch_versions = channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE(
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1,
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    before_text = """
-\033[2m----------------------------------------------------\033[0m-
                                        \033[0;32m,--.\033[0;30m/\033[0;32m,-.\033[0m
\033[0;34m        ___     __   __   __   ___     \033[0;32m/,-._.--~\'\033[0m
\033[0;34m  |\\ | |__  __ /  ` /  \\ |__) |__         \033[0;33m}  {\033[0m
\033[0;34m  | \\| |       \\__, \\__/ |  \\ |___     \033[0;32m\\`-._,-`-,\033[0m
                                        \033[0;32m`._,._,\'\033[0m
\033[0;35m  nf-core/funcprofiler ${workflow.manifest.version}\033[0m
-\033[2m----------------------------------------------------\033[0m-
"""
    after_text = """${workflow.manifest.doi ? "\n* The pipeline\n" : ""}${workflow.manifest.doi.tokenize(",").collect { doi -> "    https://doi.org/${doi.trim().replace('https://doi.org/', '')}" }.join("\n")}${workflow.manifest.doi ? "\n" : ""}
* The nf-core framework
    https://doi.org/10.1038/s41587-020-0439-x

* Software dependencies
    https://github.com/nf-core/funcprofiler/blob/master/CITATIONS.md
"""
    command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --outdir <OUTDIR>"
    //
    // Validate parameters and generate parameter summary to stdout
    //
    UTILS_NFSCHEMA_PLUGIN(
        workflow,
        validate_params,
        null,
        help,
        help_full,
        show_hidden,
        before_text,
        after_text,
        command,
        false
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE(
        nextflow_cli_args
    )

    //
    // Create channel from input file provided through params.input
    //

    Channel
        .fromList(samplesheetToList(params.input, "assets/schema_input.json"))
        .set { ch_samplesheet }

    //
    // Create channel from databases file provided through params.databases
    //
    Channel
        .fromList(samplesheetToList(params.databases, "assets/schema_database.json"))
        .set { ch_databases }

    emit:
    samplesheet = ch_samplesheet
    databases = ch_databases
    versions = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {
    take:
    email //  string: email address
    email_on_fail //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    hook_url //  string: hook URL for notifications
    multiqc_report //  string: Path to MultiQC report

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def multiqc_reports = multiqc_report.toList()

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs,
                multiqc_reports.getVal(),
            )
        }

        completionSummary(monochrome_logs)
    }

    workflow.onError {
        log.error("Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting")
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// Validate channels from input samplesheet
//
def validateInputSamplesheet(input) {
    def (metas, fastqs, fasta) = input[1..3]

    // Check that multiple runs of the same sample are of the same datatype i.e. single-end / paired-end
    def endedness_ok = metas.collect { meta -> meta.single_end }.unique().size == 1
    if (!endedness_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must be of the same datatype i.e. single-end or paired-end: ${metas[0].id}")
    }

    return [metas[0], fastqs, fasta]
}

//
// Generate methods description for MultiQC
//
def toolCitationText() {
    def text_qc = ["Read quality was assessed with FastQC (Andrews 2010)."].join(' ').trim()

    def shortread_qc_citations = [
        'fastp': "fastp (Chen et al. 2018)",
        'adapterremoval': "AdapterRemoval (Schubert et al. 2016)",
        'trimmomatic': "Trimmomatic (Bolger et al. 2014)",
        'cutadapt': "Cutadapt (Martin 2011)",
        'trimgalore': "Trim Galore! (Krueger 2015)",
        'bbduk': "BBDuk (Bushnell 2022)",
        'leehom': "leeHom (Renaud et al. 2014)",
    ]

    def complexityfilter_citations = [
        'bbduk': "BBDuk (Bushnell 2022)",
        'prinseqplusplus': "PRINSEQ++ (Cantu et al. 2019)",
        'fastp': "fastp (Chen et al. 2018)",
    ]

    def hostremoval_citations = [
        'hostile': "Hostile (Constantinides et al. 2023)",
        'deacon': "Deacon (Constantinides 2024)",
    ]

    def text_shortread_qc = [
        "Adapter clipping and quality filtering were performed with",
        "${shortread_qc_citations[params.shortread_qc_tool]}.",
        params.shortread_qc_dedup ? "Duplicate reads were removed with Clumpify (Bushnell 2022)." : "",
    ].join(' ').trim()

    def text_complexityfilter = [
        "Low-complexity reads were removed with",
        "${complexityfilter_citations[params.shortread_complexityfilter_tool]}.",
    ].join(' ').trim()

    def text_hostremoval = [
        "Host-derived reads were removed with",
        "${hostremoval_citations[params.shortread_hostremoval_tool]}.",
    ].join(' ').trim()

    def text_humann = [
        "Functional profiling was performed with",
        params.run_humann_v3 && params.run_humann_v4
            ? "HUMAnN v3 and HUMAnN v4 (Beghini et al. 2021)"
            : params.run_humann_v3
                ? "HUMAnN v3 (Beghini et al. 2021)"
                : "HUMAnN v4 (Beghini et al. 2021)",
        "using MetaPhlAn (Blanco-Míguez et al. 2023) for taxonomic marker-based profiling.",
    ].join(' ').trim()

    def text_diamond = ["Protein-level sequence alignment was performed with DIAMOND (Buchfink et al. 2021)."].join(' ').trim()

    def text_fmhfunprofiler = ["Functional profiling was additionally performed with fmhfunprofiler (Hera et al. 2024)."].join(' ').trim()

    def text_mifaser = ["Enzyme function annotation was performed with mi-faser (Zhu et al. 2017)."].join(' ').trim()

    def text_eggnogmapper = ["Functional Annotation, Orthology Assignments, and Domain Prediction was performed with eggNOG-mapper v2 (Cantalapiedra et. al 2021)"].join(' ').trim()

    def text_rgi = ["Resistome prediction was performed using RGI (Alcock et. al 2023)"].join(' ').trim()

    def citation_text = [
        "Tools used in the workflow included:",
        !params.skip_preprocessing_qc ? text_qc : "",
        params.perform_shortread_qc ? text_shortread_qc : "",
        params.perform_shortread_complexityfilter ? text_complexityfilter : "",
        params.perform_shortread_hostremoval ? text_hostremoval : "",
        params.run_humann_v3 || params.run_humann_v4 ? text_humann : "",
        params.run_diamond ? text_diamond : "",
        params.run_fmhfunprofiler ? text_fmhfunprofiler : "",
        params.run_mifaser ? text_mifaser : "",
        params.run_eggnogmapper ? text_eggnogmapper : "",
        params.run_rgi ? text_rgi : "",
        "Pipeline results statistics were summarised with MultiQC (Ewels et al. 2016).",
    ].join(' ').trim().replaceAll("[,|.] +\\.", ".")

    return citation_text
}

def toolBibliographyText() {
    def text_qc = [!params.skip_preprocessing_qc ? "<li>Andrews, S. (2010). FastQC: A Quality Control Tool for High Throughput Sequence Data [Online]. Available at: <a href=\"http://www.bioinformatics.babraham.ac.uk/projects/fastqc/\">http://www.bioinformatics.babraham.ac.uk/projects/fastqc/</a></li>" : ""].join(' ').trim()

    // One reference per preprocessing tool, keyed the same way as the params that select them.
    def bib_preprocessing = [
        'adapterremoval': "<li>Schubert, M., Lindgreen, S., & Orlando, L. (2016). AdapterRemoval v2: rapid adapter trimming, identification, and read merging. BMC Research Notes, 9, 88. <a href=\"https://doi.org/10.1186/s13104-016-1900-2\">10.1186/s13104-016-1900-2</a></li>",
        'bbduk': "<li>Bushnell, B. (2022). BBMap. <a href=\"https://sourceforge.net/projects/bbmap/\">https://sourceforge.net/projects/bbmap/</a></li>",
        'cutadapt': "<li>Martin, M. (2011). Cutadapt removes adapter sequences from high-throughput sequencing reads. EMBnet.journal, 17(1), 10–12. <a href=\"https://doi.org/10.14806/ej.17.1.200\">10.14806/ej.17.1.200</a></li>",
        'deacon': "<li>Constantinides, B. (2024). Deacon: fast alignment-free host depletion. <a href=\"https://github.com/bede/deacon\">https://github.com/bede/deacon</a></li>",
        'fastp': "<li>Chen, S., Zhou, Y., Chen, Y., & Gu, J. (2018). fastp: an ultra-fast all-in-one FASTQ preprocessor. Bioinformatics, 34(17), i884–i890. <a href=\"https://doi.org/10.1093/bioinformatics/bty560\">10.1093/bioinformatics/bty560</a></li>",
        'hostile': "<li>Constantinides, B., Hunt, M., & Crook, D. W. (2023). Hostile: accurate decontamination of microbial host sequences. Bioinformatics, 39(12), btad728. <a href=\"https://doi.org/10.1093/bioinformatics/btad728\">10.1093/bioinformatics/btad728</a></li>",
        'leehom': "<li>Renaud, G., Stenzel, U., & Kelso, J. (2014). leeHom: adaptor trimming and merging for Illumina sequencing reads. Nucleic Acids Research, 42(18), e141. <a href=\"https://doi.org/10.1093/nar/gku699\">10.1093/nar/gku699</a></li>",
        'prinseqplusplus': "<li>Cantu, V. A., Sadural, J., & Edwards, R. (2019). PRINSEQ++, a multi-threaded tool for fast and efficient quality control and preprocessing of sequencing datasets. PeerJ Preprints, 7, e27553v1. <a href=\"https://doi.org/10.7287/peerj.preprints.27553v1\">10.7287/peerj.preprints.27553v1</a></li>",
        'trimgalore': "<li>Krueger, F. (2015). Trim Galore!: a wrapper around Cutadapt and FastQC. <a href=\"https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/\">https://www.bioinformatics.babraham.ac.uk/projects/trim_galore/</a></li>",
        'trimmomatic': "<li>Bolger, A. M., Lohse, M., & Usadel, B. (2014). Trimmomatic: a flexible trimmer for Illumina sequence data. Bioinformatics, 30(15), 2114–2120. <a href=\"https://doi.org/10.1093/bioinformatics/btu170\">10.1093/bioinformatics/btu170</a></li>",
    ]

    def text_preprocessing = [
        params.perform_shortread_qc ? bib_preprocessing[params.shortread_qc_tool] : "",
        params.perform_shortread_qc && params.shortread_qc_dedup ? bib_preprocessing['bbduk'] : "",
        params.perform_shortread_complexityfilter ? bib_preprocessing[params.shortread_complexityfilter_tool] : "",
        params.perform_shortread_hostremoval ? bib_preprocessing[params.shortread_hostremoval_tool] : "",
    ].unique().join(' ').trim()

    def text_humann = [
        params.run_humann_v3 || params.run_humann_v4 ? "<li>Beghini, F., McIver, L. J., Blanco-M\u00edguez, A., Dubois, L., Asnicar, F., Maharjan, S., Mailyan, A., Thomas, A. M., Manghi, P., Valles-Colomer, M., Weingart, G., Zhang, Y., Zolfo, M., Huttenhower, C., Franzosa, E. A., & Segata, N. (2021). Integrating taxonomic, functional, and strain-level profiling of diverse microbial communities with bioBakery 3. eLife, 10, e65088. <a href=\"https://doi.org/10.7554/eLife.65088\">10.7554/eLife.65088</a></li>" : "",
        params.run_humann_v3 || params.run_humann_v4 ? "<li>Blanco-M\u00edguez, A., Beghini, F., Cumbo, F., McIver, L. J., Thompson, K. N., Zolfo, M., Manghi, P., Dubois, L., Huang, K. D., Thomas, A. M., Nickols, W. A., Piccinno, G., Piperni, E., Pun\u010doch\u00e1\u0159, M., Valles-Colomer, M., Tett, A., Giordano, F., Davies, R., Wolf, J., \u2026 Segata, N. (2023). Extending and improving metagenomic taxonomic profiling with uncharacterized species using MetaPhlAn 4. Nature Biotechnology, 41, 1633\u20131645. <a href=\"https://doi.org/10.1038/s41587-023-01688-w\">10.1038/s41587-023-01688-w</a></li>" : "",
    ].join(' ').trim()

    def text_diamond = [params.run_diamond ? "<li>Buchfink, B., Reuter, K., & Drost, H.-G. (2021). Sensitive protein alignments at tree-of-life scale using DIAMOND. Nature Methods, 18(4), 366–368. <a href=\"https://doi.org/10.1038/s41592-021-01101-x\">10.1038/s41592-021-01101-x</a></li>" : ""].join(' ').trim()

    def text_fmhfunprofiler = [params.run_fmhfunprofiler ? "<li>Hera, M. R., Liu, S., Wei, W., Rodriguez, J. S., Ma, C., & Koslicki, D. (2024). Metagenomic functional profiling: to sketch or not to sketch? Bioinformatics, 40(Suppl 2), ii165–ii173. <a href=\"https://doi.org/10.1093/bioinformatics/btae397\">10.1093/bioinformatics/btae397</a></li>" : ""].join(' ').trim()

    def text_mifaser = [
        params.run_mifaser ? "<li>Zhu, C., Miller, M., Marpaka, S., Vaysberg, P., R\u00fchlemann, M. C., Wu, G., Heinsen, F.-A., Tempel, M., Woodhouse, L., Burkhardt, L., Tams, R., Knecht, C., Heinig, M., Franke, A., Huser, T., & Bromberg, Y. (2017). Functional sequencing read annotation for high precision microbiome analysis. Nucleic Acids Research, 46(4), e23. <a href=\"https://doi.org/10.1093/nar/gkx1209\">10.1093/nar/gkx1209</a></li>" : "",
        params.run_mifaser ? "<li>Mahlich, Y., Zhu, C., Chung, H., Velaga, P. K., De Paolis Kaluza, M. C., Radivojac, P., Bromberg, Y. (2023). Learning from the unknown: exploring the range of bacterial functionality. Nucleic Acids Research. <a href=\"https://doi.org/10.1093/nar/gkad757\">10.1093/nar/gkad757</a></li>" : "",
        params.run_mifaser ? "<li>Zhu, C., Delmont, T. O., Vogel, T. M., & Bromberg, Y. (2015). Functional basis of microorganism classification. PLoS Computational Biology, 11(8), e1004472. <a href=\"https://doi.org/10.1371/journal.pcbi.1004472\">10.1371/journal.pcbi.1004472</a></li>" : "",
    ].join(' ').trim()

    def text_eggnggmapper = [params.run_eggnogmapper ? "<li>Carlos P Cantalapiedra, Ana Hernández-Plaza, Ivica Letunic, Peer Bork, Jaime Huerta-Cepas, eggNOG-mapper v2: Functional Annotation, Orthology Assignments, and Domain Prediction at the Metagenomic Scale, Molecular Biology and Evolution, Volume 38, Issue 12, December 2021, <a href = \"https://doi.org/10.1093/molbev/msab293\">0.1093/molbev/msab293</a></li>" : ""].join(' ').trim()

    def text_rgi = [params.run_rgi ? "<li>Alcock et al. 2023. CARD 2023: expanded curation, support for machine learning, and resistome prediction at the Comprehensive Antibiotic Resistance Database. Nucleic Acids Research<a href = \"https://doi.org/10.1093/molbev/msab293\"<a href=\"https://pubmed.ncbi.nlm.nih.gov/36263822/\">pubmed.ncbi.nlm.nih.gov/36263822</a></li>" : ""].join(' ').trim()

    def reference_text = [
        text_qc,
        text_preprocessing,
        text_humann,
        text_eggnggmapper,
        text_rgi,
        text_diamond,
        text_fmhfunprofiler,
        text_mifaser,
        "<li>Ewels, P., Magnusson, M., Lundin, S., & Käller, M. (2016). MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics, 32(19), 3047–3048. <a href=\"https://doi.org/10.1093/bioinformatics/btw354\">10.1093/bioinformatics/btw354</a></li>",
    ].join(' ').trim()

    return reference_text
}

def methodsDescriptionText(mqc_methods_yaml) {
    // Convert  to a named map so can be used as with familiar NXF ${workflow} variable syntax in the MultiQC YML file
    def meta = [:]

    meta.workflow = workflow.toMap()
    meta["manifest_map"] = workflow.manifest.toMap()

    // Pipeline DOI
    if (meta.manifest_map.doi) {
        // Using a loop to handle multiple DOIs
        // Removing `https://doi.org/` to handle pipelines using DOIs vs DOI resolvers
        // Removing ` ` since the manifest.doi is a string and not a proper list
        def temp_doi_ref = ""
        def manifest_doi = meta.manifest_map.doi.tokenize(",")
        manifest_doi.each { doi_ref ->
            temp_doi_ref += "(doi: <a href=\'https://doi.org/${doi_ref.replace("https://doi.org/", "").replace(" ", "")}\'>${doi_ref.replace("https://doi.org/", "").replace(" ", "")}</a>), "
        }
        meta["doi_text"] = temp_doi_ref.substring(0, temp_doi_ref.length() - 2)
    }
    else {
        meta["doi_text"] = ""
    }
    meta["nodoi_text"] = meta.manifest_map.doi ? "" : "<li>If available, make sure to update the text to include the Zenodo DOI of version of the pipeline used. </li>"

    // meta["tool_citations"] = ""
    // meta["tool_bibliography"] = ""

    meta["tool_citations"] = toolCitationText().replaceAll(", \\.", ".").replaceAll("\\. \\.", ".").replaceAll(", \\.", ".")
    meta["tool_bibliography"] = toolBibliographyText()

    def methods_text = mqc_methods_yaml.text

    def engine = new groovy.text.SimpleTemplateEngine()
    def description_html = engine.createTemplate(methods_text).make(meta)

    return description_html.toString()
}
