// TODO nf-core: If in doubt look at other nf-core/modules to see how we are doing things! :)
//               https://github.com/nf-core/modules/tree/master/modules/nf-core/
//               You can also ask for help via your pull request or on the #modules channel on the nf-core Slack workspace:
//               https://nf-co.re/join
// TODO nf-core: A module file SHOULD only define input and output files as command-line parameters.
//               All other parameters MUST be provided using the "task.ext" directive, see here:
//               https://www.nextflow.io/docs/latest/process.html#ext
//               where "task.ext" is a string.
//               Any parameters that need to be evaluated in the context of a particular sample
//               e.g. single-end/paired-end data MUST also be defined and evaluated appropriately.
// TODO nf-core: Software that can be piped together SHOULD be added to separate module files
//               unless there is a run-time, storage advantage in implementing in this way
//               e.g. it's ok to have a single module for bwa to output BAM instead of SAM:
//                 bwa mem | samtools view -B -T ref.fasta
// TODO nf-core: Optional inputs are not currently supported by Nextflow. However, using an empty
//               list (`[]`) instead of a file can be used to work around this issue.

process MIFASER {
    tag "$meta.id"
    label 'process_medium'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'ghcr.io/vdblab/mifaser:1.64c':
        'ghcr.io/vdblab/mifaser:1.64c' }"
    input:
    tuple val(meta), path(reads)
    path db_path

    output:
    // TODO nf-core: Named file extensions MUST be emitted for ALL output channels
    tuple val(meta), path("*multi_ec.tsv"), emit: multi_ec
    tuple val(meta), path("*analysis.tsv"), emit: analysis
    tuple val(meta), path("*ec_count.tsv"), emit: ec_counts
    path "versions.yml",                    emit: versions
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def input_string = meta.single_end ? "-f" : "-l"
    """
    mifaser \\
        $args \\
        $input_string ${reads} \\
        --threads 1 \\
        --cpu  $task.cpus \\
        --databasefolder ${db_path} \\
        --outputfolder mifaser-${prefix}/

    for suf in multi_ec.tsv analysis.tsv ec_count.tsv
    do
         mv mifaser-${prefix}/\$suf ${prefix}_\${suf}
    done
cat <<-END_VERSIONS > versions.yml
    MIFASER:
        MIFASER version: \$( mifaser --version 2>&1' )
        Diamond version: \$( diamond --version 2>&1' )
        database: $db_path
END_VERSIONS

    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // TODO nf-core: A stub section should mimic the execution of the original module as best as possible
    //               Have a look at the following examples:
    //               Simple example: https://github.com/nf-core/modules/blob/818474a292b4860ae8ff88e149fbcda68814114d/modules/nf-core/bcftools/annotate/main.nf#L47-L63
    //               Complex example: https://github.com/nf-core/modules/blob/818474a292b4860ae8ff88e149fbcda68814114d/modules/nf-core/bedtools/split/main.nf#L38-L54
    // TODO nf-core: If the module doesn't use arguments ($args), you SHOULD remove:
    //               - The definition of args `def args = task.ext.args ?: ''` above.
    //               - The use of the variable in the script `echo $args ` below.
    """
    echo $args
    mkdir ${prefix}
    for suf in multi_ec.tsv analysis.tsv ec_count.tsv
    do
        touch ${prefix}_\$suf
    done
touch versions.yml
    """
}
