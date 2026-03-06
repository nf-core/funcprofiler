
process HUMANN_RENORM {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::humann=3.0.0" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/humann:3.0.0--pyh5e36f6f_1"
    } else {
        container "quay.io/biocontainers/humann:3.0.0--pyh5e36f6f_1"
    }

    input:
    tuple val(meta), path(input)

    output:
    tuple val(meta), path("*_renorm.tsv.gz"), emit: renorm
    path "versions.yml"                                  , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    if [[ $input == *.gz ]]; then
        gunzip -c $input > input.tsv
    else
        mv $input input.tsv
    fi

    humann_renorm_table \\
        --input input.tsv \\
        --output ${prefix}_renorm.tsv \\
        $args

    gzip -n ${prefix}_renorm.tsv

    cat <<-END_VERSIONS > versions.yml
    ${task.process}:
        humann: \$( humann --version 2>&1 | sed 's/humann v//' )
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_renorm.tsv.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        humann: \$( humann --version 2>&1 | sed 's/humann v//' )
    END_VERSIONS
    """
}
