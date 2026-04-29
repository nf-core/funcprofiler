// Taken 98% from https://github.com/nf-core/modules/pull/1089/files
process HUMANN3 {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/humann:3.9--py312hdfd78af_0' :
        'biocontainers/humann:3.9--py312hdfd78af_0' }"

    input:
    tuple val(meta), path(input)
    tuple val(meta2), path(profile)
    path nucleotide_db
    path protein_db
    path utility_db

    output:
    tuple val(meta), path("*_genefamilies.tsv.gz") , emit: genefamilies
    tuple val(meta), path("*_pathabundance.tsv.gz"), emit: pathabundance
    tuple val(meta), path("*_pathcoverage.tsv.gz") , emit: pathcoverage
    tuple val(meta), path("*.log")                 , emit: log
    path "versions.yml"                            , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def nuc_ext = '*.ffn.gz'
    def profile_arg = profile ? "--taxonomic-profile ${profile}" : ""
    """
    PROTS_DB=\$(find -L "${protein_db}" -name "*.dmnd" -exec dirname {} \\; | head -1)
    NUCS_DB=\$(find -L "${nucleotide_db}" -name "${nuc_ext}" -exec dirname {} \\; | head -1)

    humann \\
        --input ${input} \\
        --output . \\
        --output-basename ${prefix} \\
        --nucleotide-database \${NUCS_DB} \\
        --protein-database \${PROTS_DB} \\
        --threads ${task.cpus} \\
        ${profile_arg} \\
        --o-log ${prefix}.log \\
        ${args}

    gzip -n *.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        humann: \$(humann --version 2>&1 | sed 's/humann v//')
        metaphlan: \$(metaphlan --version 2>&1 | sed 's/MetaPhlAn version //')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args

    for suf in genefamilies.tsv.gz pathabundance.tsv.gz pathcoverage.tsv.gz; do
        echo stub | gzip > ${prefix}_\${suf}
    done
    touch ${prefix}.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        humann: "3.9"
        metaphlan: "4.0.0"
    END_VERSIONS
    """
}
