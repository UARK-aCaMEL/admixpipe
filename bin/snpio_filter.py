#!/usr/bin/env python3
import argparse
import inspect
import os
from snpio import NRemover2, VCFReader, SNPioMultiQC, PopGenStatistics


def accepts(func, name):
    """True if callable `func` takes a parameter called `name`."""
    try:
        return name in inspect.signature(func).parameters
    except (TypeError, ValueError):
        return False


def get_prefix_from_vcf_path(vcf_path):
    basename = os.path.basename(vcf_path)
    for ext in [".vcf.gz", ".vcf"]:
        if basename.endswith(ext):
            return basename[: -len(ext)]
    return basename  # fallback if no known extension


def main():
    parser = argparse.ArgumentParser(
        description="Run SNPio to filter individuals and generate missingness reports"
    )
    parser.add_argument("--vcf", required=True, help="Path to the VCF file.")
    parser.add_argument(
        "--popmap", required=True, help="Path to the population map file."
    )
    parser.add_argument(
        "--ind_cov",
        type=float,
        default=0.75,
        help="Maximum allowed missingness per individual (default: 0.75)",
    )
    parser.add_argument(
        "--pop_cov",
        type=float,
        default=0.75,
        help="Maximum allowed missingness per population to retain a SNP (default: 0.75)",
    )
    parser.add_argument(
        "--min_maf",
        type=float,
        default=0.05,
        help="Maximum MAF to retain a SNP (default: 0.05)",
    )
    parser.add_argument(
        "--flank_dist",
        type=int,
        default=75,
        help="Maximum allowed distance between SNPs (default: 75)",
    )
    parser.add_argument(
        "--snp_cov",
        type=float,
        default=0.9,
        help="Maximum missing data to retain a SNP (default: 0.9)",
    )
    parser.add_argument(
        "--permutations",
        type=int,
        default=1000,
        help="Permutations/bootstraps for computing p-values with Fst, Nei distance",
    )
    parser.add_argument(
        "--jobs",
        type=int,
        default=1,
        help="Threads",
    )
    parser.add_argument(
        "--save_plots",
        action="store_true",
        help="Also write SNPio's static plot images (not used by the report)",
    )
    args = parser.parse_args()

    # extract prefix from VCF filename
    prefix = get_prefix_from_vcf_path(args.vcf)

    # read data. The report uses SNPio's data tables, not its images, so
    # skip static plots where this SNPio version supports it.
    reader_kwargs = dict(
        filename=args.vcf,
        popmapfile=args.popmap,
        force_popmap=True,
        verbose=True,
        plot_format="png",
        plot_fontsize=8,
        plot_dpi=300,
        prefix=prefix,
    )
    if accepts(VCFReader.__init__, "save_plots"):
        reader_kwargs["save_plots"] = args.save_plots
    gd = VCFReader(**reader_kwargs)

    # generate missingness reports
    gd.missingness_reports()

    # Filter VCF
    nrm = NRemover2(gd)
    gd_filt = (
        nrm.filter_missing_pop(args.pop_cov)
        .filter_monomorphic(exclude_heterozygous=False)
        .thin_loci(remove_all=True, size=args.flank_dist)
        .filter_missing(args.snp_cov)
        .filter_missing_sample(args.ind_cov)
        .filter_maf(args.min_maf)
        .resolve()
    )
    nrm.plot_sankey_filtering_report()
    gd_filt.missingness_reports(prefix="filtered")

    # Write the filtered VCF using the modified prefix
    output_vcf = f"{prefix}.filter.vcf"
    gd_filt.write_vcf(output_vcf)

    # Compute pop-gen summary statistics on the filtered object
    # SNPio >= 1.6.13 renamed fst_method to method
    pgs = PopGenStatistics(gd_filt)
    method_arg = (
        "method" if accepts(pgs.summary_statistics, "method") else "fst_method"
    )
    pgs.summary_statistics(
        n_reps=args.permutations,
        n_jobs=args.jobs,
        **{method_arg: "permutation"},
    )
    pgs.pca()

    # Generate report
    SNPioMultiQC.build(
        prefix=prefix,
        output_dir="multiqc",
        title="SNPio Report",
        overwrite=True
    )


if __name__ == "__main__":
    main()
