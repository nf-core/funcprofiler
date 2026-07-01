process FMHFUNPROFILER {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fmh-funprofiler:1.1.1--pyh106432d_0' :
        'quay.io/biocontainers/fmh-funprofiler:1.1.1--pyh106432d_0' }"

    input:
    tuple val(meta), path(fastqs)
    tuple val(dbmeta), path(fmhfunprofiler_db)

    output:
    tuple val(meta), path("*.fmhfunprofiler.ko"), emit: ko
    tuple val("${task.process}"), val('fmh-funprofiler'), val("20250930a"), emit: versions_fmhfunprofiler, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = dbmeta.db_params
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (args.split(' ').size() != 2) {
        throw new IllegalArgumentException("fmh-funcprofiler must be configured with 2 ints (kmer and sketch db args) , but got ${args.size()}:  ${args}")
    }
    """
    funcprofiler  \\
        ${fastqs} \\
        ${fmhfunprofiler_db} \\
        ${args}  \\
        ${prefix}.fmhfunprofiler.ko

    """

    stub:
    def args = dbmeta.db_params
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo ${args} > ${prefix}.fmhfunprofiler.ko

    """
}
