# nf-core/funcprofiler: Output

## Introduction

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

- [FastQC](#fastqc) - Raw read QC and preprocessing
- [HUMANn v3 / v4](#humann-v3--v4) - Functional profiling via MetaPhlAn + HUMANn _(optional)_
- [FMH FunProfiler](#fmh-funprofiler) - Sketch-based functional profiling _(optional)_
- [mifaser](#mifaser) - Read-level functional profiling _(optional)_
- [DIAMOND blastx](#diamond-blastx) - Translated alignment against a protein database _(optional)_
- [EggNOG-mapper](#eggnog-mapper) - Functional annotation via orthology assignment _(optional)_
- [RGI BWT](#rgi-bwt) - Antimicrobial resistance gene identification _(optional)_
- [MultiQC](#multiqc) - Aggregate report describing results and QC from the whole pipeline
- [Pipeline information](#pipeline-information) - Report metrics generated during the workflow execution

---

### FastQC

- [Short reads QC and preprocessing](https://nf-co.re/subworkflows/fastq_shortreads_preprocess_qc/), see [Output section](https://nf-co.re/subworkflows/fastq_shortreads_preprocess_qc/#output) for details.
- Long reads QC and preprocessing (work in progress)

---

### HUMANn v3 / v4

Enabled with `--run_humann_v3` or `--run_humann_v4`. Each sample is first run through MetaPhlAn to generate a taxonomic profile, which guides HUMANn functional profiling.

<details markdown="1">
<summary>Output files</summary>

- `humann_v3/<sample>/` or `humann_v4/<sample>/`
  - `*_genefamilies.tsv`: Gene family abundances in reads per kilobase (RPK), stratified by contributing species.
  - `*_pathabundance.tsv`: Metabolic pathway abundances in RPK, stratified by species contribution.
  - `*_pathcoverage.tsv`: Pathway coverage scores (0–1), indicating the fraction of reactions detected per pathway.
- `metaphlan/<sample>/`
  - `*_profile.txt`: Species-level taxonomic abundance profile used as input to HUMANn.

</details>

---

### FMH FunProfiler

Enabled with `--run_fmhfunprofiler`. Uses FracMinHash sketching to rapidly assign reads to functional categories.

<details markdown="1">
<summary>Output files</summary>

- `fmhfunprofiler/<sample>/`
  - `*.ko.txt`: KO (KEGG Orthology) abundance table for the sample.

</details>

---

### mifaser

Enabled with `--run_mifaser`. Maps reads to functional databases at the protein level to produce enzyme function profiles.

<details markdown="1">
<summary>Output files</summary>

- `mifaser/<db_name>/<sample>/`
  - `analysis.tsv`: Tab-separated table of functional assignments with read counts per enzyme function (EC number).
  - `analysis.log`: Log file with run statistics including number of reads processed and assigned.

</details>

---

### DIAMOND blastx

Enabled with `--run_diamond`. Performs fast translated alignment of metagenomic reads against a protein reference database. Each read is aligned in all six reading frames and only significant hits are reported.

<details markdown="1">
<summary>Output files</summary>

- `diamond/<db_name>/`
  - `*.tsv`: Tabular alignment results (BLAST tabular format 6) with one row per query-subject hit.
  - `*.log`: DIAMOND run log containing alignment statistics (query count, alignment rate, etc.).

</details>

Requires a pre-built `.dmnd` database (see [usage docs](usage.md#diamond-blastx)).

---

### EggNOG-mapper

Enabled with `--run_eggnogmapper`. Assigns functional annotations to sequences by mapping them to orthologous groups in the EggNOG database.

<details markdown="1">
<summary>Output files</summary>

- `eggnogmapper/<db_name>/`
  - `*.emapper.annotations`: TSV file with functional annotations per query sequence, including GO terms, KEGG pathways, COG categories, and more.
  - `*.emapper.seed_orthologs`: TSV linking query sequences to their best seed orthologs _(optional, produced when search is performed)_.
  - `*.emapper.hits`: TSV with raw search hits from the search phase _(optional)_.

</details>

---

### RGI BWT

Enabled with `--run_rgi`. Aligns reads against the CARD database using Bowtie2/BWA to identify antimicrobial resistance genes.

<details markdown="1">
<summary>Output files</summary>

- `rgi/<db_name>/`
  - `*.txt`: Tab-separated AMR gene hit table with gene family, resistance mechanism, drug class, and read counts.
  - `*.json`: Full RGI output in JSON format with detailed per-hit annotations.

</details>

---

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.
  - `multiqc_plots/`: directory containing static images from the report in various formats.

</details>

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in the report data directory.

Results generated by MultiQC collate pipeline QC from supported tools e.g. FastQC. The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.

---

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Parameters used by the pipeline run: `params.json`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
