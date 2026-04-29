process HUMANN_RENORM {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/humann:3.9--py312hdfd78af_0' :
        'biocontainers/humann:3.9--py312hdfd78af_0' }"

    input:
    tuple val(meta), path(input)

    output:
    tuple val(meta), path("*_renorm.tsv.gz"), emit: renorm
    tuple val("${task.process}"), val('humann'), eval("humann --version 2>/dev/null | sed 's/humann v//'"), emit: versions_humann, topic: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    if [[ ${input} == *.gz ]]; then
        gunzip -c ${input} > input.tsv
    else
        cp ${input} input.tsv
    fi

    humann_renorm_table \\
        --input input.tsv \\
        --output ${prefix}_renorm.tsv \\
        ${args}

    gzip -n ${prefix}_renorm.tsv
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "stub" | gzip > ${prefix}_renorm.tsv.gz
    """
}
