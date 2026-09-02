//
// Local module: there is no nf-core/modules HUMAnN 4 module, because HUMAnN 4 is still an alpha
// release with no Bioconda package or Biocontainer of its own. The script follows the nf-core
// humann3 modules; the container is a community build carrying humann 4.0.0.alpha.1.
//
process HUMANN4_REGROUP {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container 'ghcr.io/vdblab/biobakery-profiler:4.0.6--4.0.0.alpha.1-final_smaller-pt2'

    input:
    tuple val(meta), path(input)
    val groups
    path utility_db

    output:
    tuple val(meta), path("*_regroup.tsv.gz"), emit: regroup
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
    STATIC_CONFIG=`python -c "import humann; print(humann.__file__.replace('__init__.py', 'humann.cfg'))"`
    cat \$STATIC_CONFIG  | sed "s|utility_mapping = .*|utility_mapping = ${utility_db}|g" > humann.cfg
    export HUMANN_CONFIG=humann.cfg
    humann_config --print
    humann_regroup_table \\
        --input input.tsv \\
        --output ${prefix}_regroup.tsv \\
        --groups ${groups} \\
        ${args}

    gzip -n ${prefix}_regroup.tsv
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "stub" | gzip > ${prefix}_regroup.tsv.gz
    """
}
