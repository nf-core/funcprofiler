
process HUMANNREGROUP {
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
    val groups

    output:
    tuple val(meta), path("*_regroup.tsv.gz"), emit: regroup
    path "versions.yml"                      , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    if [[ $input == *.gz ]]; then
        gunzip -c $input > input.tsv
    else
        mv $input input.tsv
    fi

    humann_regroup_table \\
        --input input.tsv \\
        --output ${prefix}_regroup.tsv \\
        --groups $groups \\
        $args

    gzip -n ${prefix}_regroup.tsv

    cat <<-END_VERSIONS > versions.yml
    ${task.process}:
        ${humann}: \$( humann --version 2>&1 | sed 's/humann v//' )
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_regroup.tsv.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        humann: \$( humann --version 2>&1 | sed 's/humann v//' )
    END_VERSIONS
    """
}
