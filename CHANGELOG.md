# nf-core/funcprofiler: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0 - [unreleased<!-- TODO nf-core: replace with date on release -->]

Initial release of nf-core/funcprofiler, created with the [nf-core](https://nf-co.re/) template.

Read-based functional profiling of short-read microbiome sequencing data with the following profilers, all off by default and each enabled with its own `--run_<tool>` flag:

- [HUMAnN](https://huttenhower.sph.harvard.edu/humann/) v3 and v4, each preceded by a [MetaPhlAn](https://github.com/biobakery/MetaPhlAn) taxonomic prescreen and followed by `humann_regroup_table`
- [FMH FunProfiler](https://github.com/KoslickiLab/fmh-funprofiler)
- [mi-faser](https://bromberglab.org/project/mifaser/)
- [RGI](https://github.com/arpcard/rgi) `bwt`, against CARD
- [DIAMOND](https://github.com/bbuchfink/diamond) `blastx` (beta)
- [eggNOG-mapper](https://github.com/eggnogdb/eggnog-mapper) (beta)

This release performs no read QC or preprocessing; reads are expected to arrive already trimmed, quality filtered and host decontaminated.
Long-read platforms are not supported.

### `Added`

### `Fixed`

### `Dependencies`

### `Deprecated`
