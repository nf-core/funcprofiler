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



process HUMANN_HUMANN {
    tag "$meta.id"
    label 'process_high'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::humann=3.0.0" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/humann:3.0.0--pyh5e36f6f_1"
    } else {
        container "quay.io/biocontainers/humann:3.0.0--pyh5e36f6f_1"
    }

    input:
//    tuple val(meta), path(input)
    tuple val(meta), path(input)
    tuple path(profile)
//    tuple val(pangenome_meta), path(pangenome_db), val(pangenome_db_index_name)
    tuple val(nucleotide_meta), path(nucleotide_db)
    tuple val(protein_meta), path(protein_db)

    output:
    tuple val(meta), path("*_genefamilies.tsv.gz") , emit: genefamilies
    tuple val(meta), path("*_pathabundance.tsv.gz"), emit: pathabundance
    tuple val(meta), path("*_pathcoverage.tsv.gz") , emit: pathcoverage
    tuple val(meta), path("*.log")                 , emit: log
    path "versions.yml"                            , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // TODO: I never got this to successfully run
    //  def pangenome_string = "--metaphlan-options \"-t rel_ab --bowtie2db ./${pangenome_db} --index ${pangenome_db_index_name} \""
    def pangenome_string = "--taxonomic-profile ${profile}"
    """

    humann \\
        $args \\
        --threads ${task.cpus} \\
        --input $input \\
        --protein-database $protein_db \\
        --nucleotide-database $nucleotide_db \\
        --output-basename $prefix \\
        $pangenome_string \\
	${args} \\
        --o-log ${prefix}.log \\
        --output .


    gzip -n *.tsv

    cat <<-END_VERSIONS > versions.yml
    ${getProcessName(task.process)}:
        ${getSoftwareName(task.process)}: \$( humann --version 2>&1 | sed 's/humann v//' )
        Protein database: $protein_db
        Nucleotide database: $nucleotide_db
        Metaphlan profile or database: $pangenome_string
    END_VERSIONS
    """
}
