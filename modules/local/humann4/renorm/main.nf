//
// Local module: there is no nf-core/modules HUMAnN 4 module, because HUMAnN 4 is still an alpha
// release with no Bioconda package or Biocontainer of its own. The script follows the nf-core
// humann3 modules; the container is a community build carrying humann 4.0.0.alpha.1.
//
process HUMANN4_RENORM {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container 'ghcr.io/vdblab/biobakery-profiler:4.0.6--4.0.0.alpha.1-final_smaller-pt2'

    input:
    tuple val(meta), path(input)

    output:
    tuple val(meta), path("*_renorm.tsv.gz"), emit: renorm
    tuple val("${task.process}"), val('HUMAnN'), eval("humann --version 2>&1 | sed 's/humann v//'"), emit: versions_humann, topic: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    if [[ ${input} == *.gz ]]; then
        gunzip -c ${input} > input.tsv
    else
        mv ${input} input.tsv
    fi

    humann_renorm_table \\
        --input input.tsv \\
        --output ${prefix}_renorm.tsv \\
        ${args}

    gzip -n ${prefix}_renorm.tsv
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "stub" | gzip > ${prefix}_renorm.tsv.gz
    """
}
