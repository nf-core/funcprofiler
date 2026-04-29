process FMHFUNPROFILER {
    tag "${meta.id}"
    label 'process_medium'

    //    conda "${moduleDir}/environment.yml"
    container 'ghcr.io/vdblab/fmhfunprofiler:20250930a'

    input:
    tuple val(meta), path(fastqs)
    tuple val(dbmeta), path(fmhfunprofiler_db)

    output:
    // TODO nf-core: Named file extensions MUST be emitted for ALL output channels
    tuple val(meta), path("*.fmhfuncprofiler.ko"), emit: ko
    // TODO nf-core: List additional required output channels/values here
    tuple val("${task.process}"), val('fmh-funprofiler'), val("ghcr.io/vdblab/fmhfunprofiler:20250930a"), emit: versions_fmhfunprofiler, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = dbmeta.db_params
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (args.split(' ').size() != 2) {
        throw new IllegalArgumentException("fmh-funcprofiler must be configured with 2 ints (kmer and sketch db args) , but got ${args.size()}:  ${args}")
    }
    """
    funcprofiler.py  \\
        ${fastqs} \\
        ${fmhfunprofiler_db} \\
        ${args}  \\
        ${prefix}.fmhfuncprofiler.ko

    """

    stub:
    def args = dbmeta.db_params
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo ${args} > ${prefix}.fmhfuncprofiler.ko

    """
}
