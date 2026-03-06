// Taken 98% from https://github.com/nf-core/modules/pull/1089/files

def getProcessName(task_process) {
    return task_process.tokenize(':')[-1]
}

def containerMap = [
    'HUMANN3': 'ghcr.io/vdblab/biobakery-profiler:4.0.5--3.6.1',
    'HUMANN4': 'ghcr.io/vdblab/biobakery-profiler:4.0.6--4.0.0.alpha.1-final'
]
def condaMap = [
    'HUMANN3': 'bioconda::humann=3.6.1',
    'HUMANN4': 'bioconda::humann=4.0.0.alpha.1-final'
]
def extMap = [
    'HUMANN3': '*.ffn.gz',
    'HUMANN4': '*.fna.gz'
]


process HUMANN_HUMANN {
    tag "$meta.id"
    label 'process_high'

    conda (params.enable_conda ? { condaMap[getProcessName(task.process)] } : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container)	{
        container { "docker://" + containerMap[getProcessName(task.process)] }
    } else {
    container { containerMap[getProcessName(task.process)] }
    }
    input:
    tuple val(meta), path(input)
    tuple val(meta), path(profile)
    path nucleotide_db
    path protein_db
    path utility_db

    output:
    tuple val(meta), path("*_genefamilies.tsv.gz") , emit: genefamilies
    tuple val(meta), path("*_pathabundance.tsv.gz"), emit: pathabundance
    tuple val(meta), path("*_pathcoverage.tsv.gz") , emit: pathcoverage, optional:true
    tuple val(meta), path("*_reactions.tsv.gz")    , emit: reactions, optional:true
    tuple val(meta), path("*.log")                 , emit: log
    path "versions.yml"                            , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (extMap[getProcessName(task.process)] == null){
	throw new IllegalArgumentException("this process must be aliased to either HUMANN3 or HUMANN4 to ensure the right parameters and containers are used; detected ${getProcessName(task.process)}")
    }
    def nuc_ext = extMap[getProcessName(task.process)]
    // TODO: I never got this to successfully run
    //  def pangenome_string = "--metaphlan-options \"-t rel_ab --bowtie2db ./${pangenome_db} --index ${pangenome_db_index_name} \""
    def pangenome_string = "--taxonomic-profile ${profile}"
    """
    PROTS_DB=`find -L "${protein_db}" -name "*.dmnd" -exec dirname {} \\;`
    nuclist=`find -L "${nucleotide_db}" -name "${nuc_ext}" -print -quit `
    NUCS_DB=\$(dirname \$nuclist)

    STATIC_CONFIG=`python -c "import humann; print(humann.__file__.replace('__init__.py', 'humann.cfg'))"`
    cat \$STATIC_CONFIG  | sed "s|utility_mapping = .*|utility_mapping = ${utility_db}|g" > humann.cfg
    export HUMANN_CONFIG=humann.cfg

    find \${NUCS_DB}
    humann \\
        $args \\
        --threads ${task.cpus} \\
        --input $input \\
        --protein-database \${PROTS_DB} \\
        --nucleotide-database \${NUCS_DB} \\
        --output-basename $prefix \\
        $pangenome_string \\
	${args} \\
        --o-log ${prefix}.log \\
        --output .


    gzip -n *.tsv

cat <<-END_VERSIONS > versions.yml
    HUMANN:
        Humann version: \$( humann --version 2>&1 | sed 's/humann v//' )
        Protein database: $protein_db
        Nucleotide database: $nucleotide_db
        Metaphlan profile or database: $pangenome_string
END_VERSIONS
    """
    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo $args

    for suf in _genefamilies.tsv.gz _pathabundance.tsv.gz _pathcoverage.tsv.gz _reactions.tsv.gz .log
    do
        touch ${prefix}_\$suf
    done
touch versions.yml
    """
}
