# nf-core/funcprofiler: Usage

## :warning: Please read this documentation on the nf-core website: [https://nf-co.re/funcprofiler/usage](https://nf-co.re/funcprofiler/usage)

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

**nf-core/funcprofiler** performs read-based functional profiling of microbiome sequencing data.
It requires two input CSV files: a samplesheet describing your samples and a databases sheet describing the profiling databases to use.

## Read preprocessing

The pipeline does not perform read QC or preprocessing!
Reads are expected to arrive already trimmed, quality filtered and host decontaminated.

We recommend users run nf-core/funcprofiler after running [nf-core/taxprofiler](https://nf-co.re/taxprofiler), which already covers short-read preprocessing, and provides complimentary information.
Adopting the nf-core [`fastq_shortreads_preprocess_qc`](https://nf-co.re/subworkflows/fastq_shortreads_preprocess_qc/) subworkflow is planned for a later release.

## Samplesheet input

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline.
Use this parameter to specify its location.
It has to be a comma-separated file with a header row and the columns shown below.

```bash
--input '[path to samplesheet file]'
```

| Column                | Required | Description                                                                                                                                            |
| --------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `sample`              | Yes      | Sample name. Rows with the same `sample` name (and different `run_accession`) are merged before profiling.                                             |
| `run_accession`       | Yes      | Unique run identifier (e.g. `RUN1`, `SRR12345`). Used to distinguish multiple sequencing runs of the same sample.                                      |
| `instrument_platform` | Yes      | Sequencing platform. Must be one of: `ABI_SOLID`, `BGISEQ`, `CAPILLARY`, `COMPLETE_GENOMICS`, `DNBSEQ`, `HELICOS`, `ILLUMINA`, `ION_TORRENT`, `LS454`. |
| `fastq_1`             | Yes      | Full path to gzipped already preprocessed FASTQ file for read 1. Must end in `.fastq.gz` or `.fq.gz`.                                                  |
| `fastq_2`             | No       | Full path to gzipped already preprocessed FASTQ file for read 2 (paired-end only). Leave empty for single-end reads.                                   |
| `fasta`               | No       | Unused. The column is retained for compatibility with nf-core/taxprofiler samplesheets and must be left empty.                                         |

> [!NOTE]
> `fastq_1` must be provided for each row! We do **not** support `OXFORD_NANOPORE` or `PACBIO_SMRT` platforms, as long reads are incompatible (or at least, require nuanced interpretation) with most of these tools. Similarly, we do not support `fasta` input, as assembly-based pipelines like nf-core/funcscan would be more appropriate.

### Example samplesheet

```csv
sample,run_accession,instrument_platform,fastq_1,fastq_2,fasta
SAMPLE1,RUN1,ILLUMINA,/data/sample1_R1.fastq.gz,/data/sample1_R2.fastq.gz,
SAMPLE1,RUN2,ILLUMINA,/data/sample1_lane2_R1.fastq.gz,/data/sample1_lane2_R2.fastq.gz,
SAMPLE2,RUN1,ILLUMINA,/data/sample2_R1.fastq.gz,,
```

In this example, `SAMPLE1` has two runs which will be merged before profiling. `SAMPLE2` is single-end short reads.

## Enabling profilers

The pipeline will only run the profilers you explicitly turn on, and for which a database has been specified in your database samplesheet:

| Flag                   | Profiler        | Status                  |
| ---------------------- | --------------- | ----------------------- |
| `--run_humann_v3`      | HUMAnN v3       | Available               |
| `--run_humann_v4`      | HUMAnN v4       | Available               |
| `--run_fmhfunprofiler` | FMH FunProfiler | Available               |
| `--run_mifaser`        | mi-faser        | Available               |
| `--run_rgi`            | RGI BWT         | Available               |
| `--run_diamond`        | DIAMOND blastx  | Work in progress / beta |
| `--run_eggnogmapper`   | eggNOG-mapper   | Work in progress / beta |

> [!NOTE]
> Each `--run_` flag requires a matching database entry in the `--databases` CSV. Database rows for tools that are not enabled will be ignored.

> [!WARNING]
> Beta means the profiler runs and produces output, but database handling and output behaviour have not been validated end to end, and neither is covered by the full-size test.
> Interpret the results with caution and check them independently before using them in an analysis.

## Databases input

```bash
--databases '[path to databases file]'
```

The databases sheet is a comma-separated file that specifies which databases to use for each profiler.
Only tools enabled via `--run_<tool>` flags will use the corresponding database entries.

Use the `db_name` column to record the database release or version used for the run, for example `uniref90_v3`, `eggnog_v5`, `card_v3`, or `GS-24-all`.

| Column      | Required | Description                                                                                                                                                   |
| ----------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tool`      | Yes      | Profiler name. Must be one of: `humann_v3`, `humann_v4`, `fmhfunprofiler`, `mifaser`, `diamond`, `rgi`, `eggnogmapper`.                                       |
| `db_name`   | Yes      | Name of the database as a whole, i.e. the release or version you want recorded in the results. All rows belonging to the same database must share this name.  |
| `db_entity` | No       | Name of an individual component of that database, for the tools that need more than one. Leave empty for tools that take a single database file or directory. |
| `db_params` | No       | Additional parameters to pass to the profiler (no quotes allowed).                                                                                            |
| `db_path`   | Yes      | Absolute path to the database file or directory. Gzipped TAR archives (`.tar.gz`) are automatically decompressed.                                             |

> [!IMPORTANT]
> `db_name` and `db_entity` describe two different levels. `db_name` names the database, `db_entity` names one of its parts.
> HUMAnN and eggNOG-mapper need several parts, so they take **one row per part**, all sharing the same `db_name` and each naming a different `db_entity`: `humann_metaphlan`, `humann_nucleotide`, `humann_protein` and `humann_utility` for HUMAnN, and `eggnogmapper_db` and `eggnogmapper_data_dir` for eggNOG-mapper.
> FMH FunProfiler, mi-faser, DIAMOND and RGI take a single database, so they take one row with `db_entity` left empty.

The pipeline checks the database sheet against the enabled profilers before it submits any job, so a missing component fails immediately rather than partway through a run.

### Database versions and compatibility

The pipeline passes `db_path` straight to the profiler and never checks it against the tool version, so pairing a database with a compatible tool release is up to you.
The versions a run actually used are recorded in `<outdir>/pipeline_info/nf_core_funcprofiler_software_mqc_versions.yml`.

These combinations were exercised on a human gut metagenome cohort during development; RGI, DIAMOND and HUMAnN v4 were only tested against the small CI databases.

| Tool            | Tool version | Database                                                                                                          |
| --------------- | ------------ | ----------------------------------------------------------------------------------------------------------------- |
| HUMAnN v3       | 3.6.1        | ChocoPhlAn full `v201901_v31`, UniRef90 `201901b` full, `utility_mapping` full                                    |
| MetaPhlAn       | 4.0.6        | `mpa_vJan21_CHOCOPhlAnSGB_202103`                                                                                 |
| FMH FunProfiler | 1.1.1        | KO sketches from [Zenodo record 10045253](https://zenodo.org/records/10045253), scaled 1000 / k=11 and scaled 500 |
| mi-faser        | 1.64         | `GS-24-all`, downloaded from the mi-faser website                                                                 |
| eggNOG-mapper   | 2.1.13       | eggNOG 5.0.2 data directory                                                                                       |

### HUMAnN

[HUMAnN](https://huttenhower.sph.harvard.edu/humann/) profiles the abundance of microbial metabolic pathways and gene families, guided by a MetaPhlAn taxonomic profile.
Enable it with `--run_humann_v3` or `--run_humann_v4`.

#### Database preparation

HUMAnN requires four database components per named database, each as a separate row with the same `db_name`.
The ChocoPhlAn nucleotide database, the UniRef protein database and the utility mapping files are downloaded with `humann_databases`, which ships with HUMAnN; the MetaPhlAn marker database is downloaded with `metaphlan --install`.

```bash
humann_databases --download chocophlan full /data/databases
humann_databases --download uniref uniref90_diamond /data/databases
humann_databases --download utility_mapping full /data/databases
metaphlan --install --bowtie2db /data/databases/metaphlan_db
```

See the [HUMAnN documentation](https://github.com/biobakery/humann#5-download-the-databases) for the full list of available releases.
The example below uses a HUMAnN v3-compatible UniRef90 database set; replace `uniref90_v3` with the exact release or version used in your analysis.

```csv
tool,db_name,db_entity,db_params,db_path
humann_v3,uniref90_v3,humann_metaphlan,,/data/databases/metaphlan_db
humann_v3,uniref90_v3,humann_nucleotide,,/data/databases/chocophlan
humann_v3,uniref90_v3,humann_protein,,/data/databases/uniref90_diamond
humann_v3,uniref90_v3,humann_utility,,/data/databases/utility_mapping
```

### FMH FunProfiler

[FMH FunProfiler](https://github.com/KoslickiLab/fmh-funprofiler) uses FracMinHash sketching to assign reads to KEGG Orthology (KO) categories.
Enable it with `--run_fmhfunprofiler`.

#### Database preparation

Download a pre-sketched KO database from [Zenodo record 10045253](https://zenodo.org/records/10045253), or build your own sketches with `sourmash sketch` as described in the [FMH FunProfiler README](https://github.com/KoslickiLab/fmh-funprofiler#usage).
`db_path` points at the `.sig.zip` sketch file.

FMH FunProfiler is the one tool that needs its `db_params` filled in: it takes the k-mer size and the sketch scale of the database, in that order, separated by a space.
A sketch built at k=11 and scale 1000 therefore needs `11 1000`.

```csv
tool,db_name,db_entity,db_params,db_path
fmhfunprofiler,kegg_v1,,11 1000,/data/databases/fmhfunprofiler_kegg.sig.zip
```

### mi-faser

[mi-faser](https://bromberglab.org/project/mifaser/) performs functional profiling by mapping reads to functional databases at the protein level.
Enable it with `--run_mifaser`.

#### Database preparation

Download a pre-built mi-faser database (e.g. GS-21, GS-24-all, or GS-580) from the [mi-faser website](https://bromberglab.org/project/mifaser/).
`db_path` should point to the directory containing the database files, and `db_name` should record the downloaded database version.

```csv
tool,db_name,db_entity,db_params,db_path
mifaser,GS-24-all,,,/data/databases/mifaser/GS-24-all
```

### RGI BWT

[RGI](https://card.mcmaster.ca/about) (Resistance Gene Identifier) uses the Comprehensive Antibiotic Resistance Database (CARD) to identify AMR genes.
The `bwt` subcommand aligns reads directly to CARD using Bowtie2/BWA.
Enable it with `--run_rgi`.

#### Database preparation

Download the CARD database and extract it to a directory.
The example CSV below labels the database as `card_v3`; replace this with the exact CARD release used in your analysis.

```bash
wget https://card.mcmaster.ca/latest/data
tar -xvf data ./card.json
rgi load --card_json card.json --local
```

The `db_path` in the databases CSV must point to the directory containing `card.json` and the pre-built CARD annotation files (`card_database_v*.fasta`).

```csv
tool,db_name,db_entity,db_params,db_path
rgi,card_v3,,,/data/databases/card
```

> [!NOTE]
> Wildcard variant databases are not currently supported by the pipeline. Only the core CARD database is used.

### eggNOG-mapper

[eggNOG-mapper](https://github.com/eggnogdb/eggnog-mapper) assigns functional annotations by mapping sequences to orthologous groups in the eggNOG database.
Enable it with `--run_eggnogmapper`.

> [!WARNING]
> eggNOG-mapper support is currently in beta and should be treated as work in progress. Database handling, output behavior, and downstream reporting are still being validated in the full pipeline, so use with caution and independently review results before production use or interpretation.

#### Database preparation

eggNOG-mapper requires two rows per named database: the search database (`eggnogmapper_db`) and the eggNOG data directory (`eggnogmapper_data_dir`).
Both are downloaded with `download_eggnog_data.py`, which ships with the eggnog-mapper package; see the [eggNOG-mapper wiki](https://github.com/eggnogdb/eggnog-mapper/wiki) for the available releases.

```bash
download_eggnog_data.py --data_dir /data/databases/eggnog_mapper/data -P
create_dbs.py -m diamond --dbname eggnog_proteins --data_dir /data/databases/eggnog_mapper
```

The `db_params` field of the `eggnogmapper_db` row must specify the search mode (e.g. `diamond`, `mmseqs`, `hmmer`).
The example below uses an eggNOG v5 database label; replace `eggnog_v5` with the exact eggNOG database release used in your analysis.

```csv
tool,db_name,db_entity,db_params,db_path
eggnogmapper,eggnog_v5,eggnogmapper_db,diamond,/data/databases/eggnog_mapper/eggnog_proteins.dmnd
eggnogmapper,eggnog_v5,eggnogmapper_data_dir,,/data/databases/eggnog_mapper/data
```

### DIAMOND blastx

[DIAMOND](https://github.com/bbuchfink/diamond/wiki/) is a high-throughput sequence aligner for translated (nucleotide-vs-protein) alignment.
Enable it with `--run_diamond`.

> [!WARNING]
> DIAMOND support is currently in beta and should be treated as work in progress. Database handling, output behavior, and downstream reporting are still being validated in the full pipeline, so use with caution and independently review results before production use or interpretation.

#### Database preparation

The database supplied in the `--databases` CSV must already be in DIAMOND binary format (`.dmnd`).
Build it from a versioned protein FASTA using `diamond makedb`, and use `db_name` to record the source database and release.

```bash
diamond makedb --in proteins.faa --db proteins
# produces proteins.dmnd
```

See the [DIAMOND makedb documentation](https://github.com/bbuchfink/diamond/wiki/3.-Command-line-options#makedb-options) for all available options (e.g. adding taxonomy, setting block size).

```csv
tool,db_name,db_entity,db_params,db_path
diamond,uniref90_v3,,,/data/databases/diamond
```

> [!WARNING]
> The path should point to the **directory** containing the `.dmnd` file, not the file itself. The pipeline will automatically locate the `.dmnd` file within that directory.

### Full example databases sheet

This example uses versioned database names to make the database releases traceable in the run outputs.
Replace these names and paths with the exact database releases you downloaded.

```csv
tool,db_name,db_entity,db_params,db_path
humann_v3,uniref90_v3,humann_metaphlan,,/data/databases/metaphlan_db
humann_v3,uniref90_v3,humann_nucleotide,,/data/databases/chocophlan
humann_v3,uniref90_v3,humann_protein,,/data/databases/uniref90_diamond
humann_v3,uniref90_v3,humann_utility,,/data/databases/utility_mapping
humann_v4,uniref90_v4,humann_metaphlan,,/data/databases/metaphlan4_db
humann_v4,uniref90_v4,humann_nucleotide,,/data/databases/chocophlan_v4
humann_v4,uniref90_v4,humann_protein,,/data/databases/uniref90_v4_diamond
humann_v4,uniref90_v4,humann_utility,,/data/databases/utility_mapping_v4
fmhfunprofiler,kegg_v1,,11 1000,/data/databases/fmhfunprofiler_kegg.sig.zip
mifaser,GS-24-all,,,/data/databases/mifaser/GS-24-all
rgi,card_v3,,,/data/databases/card
eggnogmapper,eggnog_v5,eggnogmapper_db,diamond,/data/databases/eggnog_mapper/eggnog_proteins.dmnd
eggnogmapper,eggnog_v5,eggnogmapper_data_dir,,/data/databases/eggnog_mapper/data
diamond,uniref90_v3,,,/data/databases/diamond
```

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run nf-core/funcprofiler \
   --input samplesheet.csv        \
   --databases databases.csv      \
   --outdir results               \
   --run_humann_v3                \
   --run_fmhfunprofiler           \
   -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

### Parameters

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

> [!WARNING]
> Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources), other infrastructural tweaks (such as output directories), or module arguments (args).

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run nf-core/funcprofiler -profile docker -params-file params.yaml
```

with:

```yaml title="params.yaml"
input: "./samplesheet.csv"
databases: "./databases.csv"
outdir: "./results/"
run_humann_v3: true
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull nf-core/funcprofiler
```

### Reproducibility

It is a good idea to specify the pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [nf-core/funcprofiler releases page](https://github.com/nf-core/funcprofiler/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducibility, you can use share and reuse [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> [!TIP]
> If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Core Nextflow arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen)

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

> [!WARNING]
> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to check if your system is supported, please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer environment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://charliecloud.io/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `wave`
  - A generic configuration profile to enable [Wave](https://seqera.io/wave/) containers. Use together with one of the above (requires Nextflow `24.03.0-edge` or later).
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter, Charliecloud, or Apptainer.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the pipeline steps, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher resources request (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#set-max-resources) and [customise process resources](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#customize-process-resources) section of the nf-core website.

### Custom Containers

In some cases, you may wish to change the container or conda environment used by a pipeline steps for a particular tool. By default, nf-core pipelines use containers and software from the [biocontainers](https://biocontainers.pro/) or [bioconda](https://bioconda.github.io/) projects. However, in some cases the pipeline specified version maybe out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#update-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#modifying-tool-arguments) section of the nf-core website.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
