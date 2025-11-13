// Import generic module functions
//include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

// params.options = [:]
// options        = initOptions(params.options)



// Taken 98% from https://github.com/nf-core/modules/pull/1089/files
def getSoftwareName(task_process) {
    return task_process.tokenize(':')[-1].tokenize('_')[0].toLowerCase()
}

//
// Extract name of module from process name using $task.process
//
def getProcessName(task_process) {
    return task_process.tokenize(':')[-1]
}



process HUMANN_HUMANN_V4 {
    tag "$meta.id"
    label 'process_high'
    publishDir "${params.outdir}"
    //, mode: params.publish_dir_mode,
//        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::humann=3.0.0" : null)

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'docker://ghcr.io/vdblab/biobakery-profiler:4.0.6--4.0.0.alpha.1-final'
        : 'ghcr.io/vdblab/biobakery-profiler:4.0.6--4.0.0.alpha.1-final'}"


    input:
    tuple val(meta), path(input)
//    tuple val(meta), path(profile)
    //    tuple val(pangenome_meta), path(pangenome_db), val(pangenome_db_index_name)
    path metaphlan_db_latest
    path nucleotide_db
    path protein_db
    path utility_db

    output:
    tuple val(meta), path("*_genefamilies.tsv.gz") , emit: genefamilies
    tuple val(meta), path("*_pathabundance.tsv.gz"), emit: pathabundance
    tuple val(meta), path("*_reactions.tsv.gz"),    emit: reactions
    tuple val(meta), path("*_metaphlan_profile.tsv.gz"), emit: metaphlan_profile
    tuple val(meta), path("*.log")                 , emit: log
    path "versions.yml"                            , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // TODO: I never got this to successfully run
 //   def pangenome_string = "--metaphlan-options \"-t rel_ab --bowtie2db ./${pangenome_db} --index ${pangenome_db_index_name} \""
    //def pangenome_string = "--taxonomic-profile ${profile}"
    """
    PROTS_DB=`find -L "${protein_db}" -name "*.dmnd" -exec dirname {} \\;`
    nuclist=`find -L "${nucleotide_db}" -name "*.fna.gz" -print -quit `
    NUCS_DB=\$(dirname \$nuclist)

    find \${NUCS_DB}

    BT2_DB=`find -L "${metaphlan_db_latest}" -name "*rev.1.bt2*" -exec dirname {} \\;`
    BT2_DB_INDEX=`find -L ${metaphlan_db_latest} -name "*.rev.1.bt2*" | sed 's/\\.rev.1.bt2.*\$//' | sed 's/.*\\///'`

    humann \\
        $args \\
        --threads ${task.cpus} \\
        --input $input \\
        --protein-database \${PROTS_DB} \\
        --nucleotide-database \${NUCS_DB} \\
        --utility-database $utility_db \\
        --output-basename $prefix \\
        --metaphlan-options \"-t rel_ab_w_read_stats --bowtie2db \${BT2_DB} --index \${BT2_DB_INDEX} \"\\
	${args} \\
        --o-log ${prefix}.log \\
        --output .


    gzip -n *.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Humann version: \$( humann --version 2>&1  )
        metaphlan: \$(metaphlan --version 2>&1 | awk '{print \$3}')
        Protein database: "${protein_db}"
        Nucleotide database: "${nucleotide_db}"
        Metaphlan profile or database: "${metaphlan_db_latest}"

    END_VERSIONS

    """
}
//    ${getProcessName(task.process)}:
//        ${getSoftwareName(task.process)}: \$( humann --version 2>&1 | sed 's/humann v//' )
