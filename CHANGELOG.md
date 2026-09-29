# aCaMEL/admixpipe: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0 - Chop Suey - [28-09-2026]

Initial release of aCaMEL/admixpipe.

### `Added`

- VCF filtering and data summaries (missingness, pairwise F<sub>ST</sub>, PCA, filtering Sankey) with SNPio.
- ADMIXTURE across K = 1…`--maxk` with replicates and cross-validation via AdmixPipe, with CLUMPAK/CLUMPP replicate alignment and distruct plots.
- Best-K selection by cross-validation, Evanno ΔK, or the elbow of L(K), L′(K) or |L″(K)| (`--bestk_method`).
- Model-fit assessment with evalAdmix for all K.
- Interactive MultiQC report with barplots, CV/Evanno plots and evalAdmix heatmaps for the best K and all K.
- Optional interactive ancestry maps (`--site_coords`) with user-supplied vector layers (`--geo_data_config`, `--geo_data_dir`).
- Full run provenance in the report: command line, run metadata, and every parameter value with its default.
- Draft methods text with tool citations in the report.
- Reproducible runs with `--seed`: each ADMIXTURE K and replicate gets its own seed drawn from it, and SNPio's F<sub>ST</sub> permutations and PCA use it too. Without `--seed`, the seed is derived from the session ID, kept by `-resume`, and recorded in the report.

### `Fixed`

- `SNPIO_FILTER` no longer stalls under amd64 emulation on Apple silicon: SNPio's static plot images, which the report does not use, are skipped (`--save_plots` in `bin/snpio_filter.py` restores them).
- Report HTML templates and the logo are staged as process inputs instead of being read from `baseDir`, so report steps also work on executors without access to the pipeline directory.
- Software versions now include distruct, the post-filtering `bcftools query`, Evanno and map-layer staging.
- The aCaMEL logo is added to the report header again; the header pattern no longer matched MultiQC 1.35.
- Reports are about half the size (109 → 57 MB on the test data): the evalAdmix heatmaps' per-cell hover labels are shorter.

### `Dependencies`

| Dependency | Old version | New version |
| ---------- | ----------- | ----------- |
| AdmixPipe  | 3.2         | 3.2.2       |
| SNPio      | 1.6.10      | 1.7.6       |

The deprecated nf-core `tabix/bgzip` and `tabix/tabix` modules are replaced by `htslib/bgziptabix`.
