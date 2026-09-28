//
// Run Steve Mussmann's Admixture Pipeline (AdmixPipe 3.0)
//

include { HTSLIB_BGZIPTABIX as DECOMPRESS_VCF } from '../../../modules/nf-core/htslib/bgziptabix/main'
include { ADMIXTUREPIPELINE } from '../../../modules/local/admixpipe/admixturepipeline.nf'
include { CLUMPAK } from '../../../modules/local/admixpipe/submitclumpak.nf'
include { CVSUM } from '../../../modules/local/admixpipe/cvsum.nf'
include { DISTRUCT } from '../../../modules/local/admixpipe/distructrerun.nf'
include { EVALADMIX } from '../../../modules/local/admixpipe/evaladmix.nf'
include { BESTK } from '../../../modules/local/bestk/main'
include { EVANNO } from '../../../modules/local/evanno/main'

workflow RUN_ADMIXPIPE {
    take:
    vcf         // [ val(meta), *.vcf or *.vcf.gz ]
    ch_popmap   // [ val(meta), popmap file ]
    seed        // value: random seed for ADMIXTURE replicates

    main:
    ch_versions = channel.empty()

    // Branch input VCF by extension
    vcf
    | branch { item ->
        vcfgz: item[1].name.endsWith('.vcf.gz')
        vcf:   item[1].name.endsWith('.vcf')
    }
    | set { ch_vcf_branch }

    // If input was vcf.gz, decompress
    DECOMPRESS_VCF(
        ch_vcf_branch.vcfgz.map { meta, file -> [ meta, file, [], [] ] },
        'decompress',
        false,
        'vcf'
    )

    // Combine uncompressed .vcf with decompressed .vcf
    DECOMPRESS_VCF.out.output
        | mix( ch_vcf_branch.vcf )
        | set { ch_vcf }

    // Pass to ADMIXTURE pipeline
    ADMIXTUREPIPELINE(
        ch_vcf,
        ch_popmap,
        seed
    )
    ch_versions = ch_versions.mix( ADMIXTUREPIPELINE.out.versions )

    // Run CLUMPAK
    CLUMPAK(
        ADMIXTUREPIPELINE.out.results,
        ADMIXTUREPIPELINE.out.inds,
        ADMIXTUREPIPELINE.out.pops,
        ADMIXTUREPIPELINE.out.args_json
    )
    ch_versions = ch_versions.mix( CLUMPAK.out.versions )

    // Run Distruct
    DISTRUCT(
        ADMIXTUREPIPELINE.out.pfiles,
        ADMIXTUREPIPELINE.out.qfiles,
        ADMIXTUREPIPELINE.out.pops,
        ADMIXTUREPIPELINE.out.inds,
        ADMIXTUREPIPELINE.out.logs,
        CLUMPAK.out.output
    )
    ch_versions = ch_versions.mix( DISTRUCT.out.versions )

    // Compute best K from crossval
    CVSUM(
        DISTRUCT.out.cv,
        DISTRUCT.out.loglik
    )
    ch_versions = ch_versions.mix( CVSUM.out.versions )

    // Run EvalAdmix
    EVALADMIX(
        ADMIXTUREPIPELINE.out.ped,
        ADMIXTUREPIPELINE.out.map,
        ADMIXTUREPIPELINE.out.pfiles,
        ADMIXTUREPIPELINE.out.qfiles,
        ADMIXTUREPIPELINE.out.qfiles_json,
        ch_popmap,
        CLUMPAK.out.output,
        DISTRUCT.out.major_clusters,
        DISTRUCT.out.cvruns_json,
        DISTRUCT.out.qfilepaths_json
    )
    ch_versions = ch_versions.mix( EVALADMIX.out.versions )

    // Evanno calculations (backup for bestK)
    EVANNO(
        CVSUM.out.ll_output
    )

    // Fetch results for the best K value
    BESTK(
        CVSUM.out.cv_output,
        EVANNO.out.metrics,
        DISTRUCT.out.best_results
    )
    ch_versions = ch_versions.mix( BESTK.out.versions )

    emit:
    best_results = DISTRUCT.out.best_results
    bestK_file   = BESTK.out.bestK_file
    bestK_clumpp = BESTK.out.bestK_clumpp
    evanno       = EVANNO.out.metrics
    inds         = ADMIXTUREPIPELINE.out.inds
    pops         = ADMIXTUREPIPELINE.out.pops
    cv_file      = CVSUM.out.cv_output
    qfilepaths   = DISTRUCT.out.qfilepaths_json
    corres       = EVALADMIX.out.corres
    fam          = EVALADMIX.out.fam
    versions     = ch_versions
}
