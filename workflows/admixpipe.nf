/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { softwareVersionsToYAML   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText   } from '../subworkflows/local/utils_nfcore_admixpipe_pipeline'
include { fullParamsSummaryMultiqc } from '../subworkflows/local/utils_nfcore_admixpipe_pipeline'

include { SNPIO_FILTER } from '../modules/local/snpio/filter.nf'
include { RUN_ADMIXPIPE } from '../subworkflows/local/run_admixpipe/main'
include { GENERATE_REPORT } from '../subworkflows/local/generate_report/main'
include { CUSTOMIZE_REPORT } from '../modules/local/report/customize_report.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ADMIXPIPE {

    take:
    ch_vcf     // [meta, vcf]
    ch_tbi     // [meta, tbi]
    ch_popmap  // [meta, popmap]
    ch_site_coords
    ch_geo_data
    ch_geo_data_dir
    multiqc_config               // string: path to a custom MultiQC config (optional)
    multiqc_logo                 // string: path to a custom MultiQC logo (optional)
    multiqc_methods_description  // string: path to a custom methods description (optional)
    outdir                       // string: output directory

    main:

    def ch_versions = channel.empty()
    def ch_multiqc_files = channel.empty()

    //
    // VCF pre-processing
    //
    // This step removes individuals with a large amount of missing data,
    // flanking variants, low variation, etc...
    // and also generates SNPio missingness reports
    SNPIO_FILTER(
        ch_vcf,
        ch_tbi,
        ch_popmap
    )
    ch_versions = ch_versions.mix(SNPIO_FILTER.out.versions)
    ch_filtered_vcf = SNPIO_FILTER.out.filtered_vcf.map { meta, file -> tuple(meta + [id: "${meta.id}_filtered"], file) }
    ch_filtered_tbi = SNPIO_FILTER.out.filtered_tbi.map { meta, file -> tuple(meta + [id: "${meta.id}_filtered"], file) }
    ch_snpio_output = SNPIO_FILTER.out.snpio_output.map { meta, dir -> tuple(meta + [id: "${meta.id}_filtered"], dir) }
    ch_snpio_multiqc_data = SNPIO_FILTER.out.multiqc_report_data.map { meta, dir -> tuple(meta + [id: "${meta.id}_filtered"], dir) }

    //
    // Run admixture pipeline on filtered dataset
    //
    RUN_ADMIXPIPE(
        ch_filtered_vcf,
        ch_popmap
    )
    ch_versions = ch_versions.mix(RUN_ADMIXPIPE.out.versions)


    //
    // Generate figures for the report
    //
    GENERATE_REPORT(
        ch_vcf,
        ch_tbi,
        ch_filtered_vcf,
        ch_filtered_tbi,
        RUN_ADMIXPIPE.out.cv_file,
        RUN_ADMIXPIPE.out.evanno,
        RUN_ADMIXPIPE.out.bestK_file,
        RUN_ADMIXPIPE.out.best_results,
        ch_snpio_output,
        ch_snpio_multiqc_data,
        RUN_ADMIXPIPE.out.bestK_clumpp,
        RUN_ADMIXPIPE.out.inds,
        RUN_ADMIXPIPE.out.pops,
        RUN_ADMIXPIPE.out.qfilepaths,
        RUN_ADMIXPIPE.out.corres,
        RUN_ADMIXPIPE.out.fam,
        ch_site_coords,
        ch_geo_data,
        ch_geo_data_dir
    )
    ch_versions = ch_versions.mix( GENERATE_REPORT.out.versions )
    ch_multiqc_files = ch_multiqc_files.mix( GENERATE_REPORT.out.mqc_files )

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name:  'admixpipe_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    def ch_workflow_summary = channel.value(fullParamsSummaryMultiqc("nextflow_schema.json"))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))
    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'admixpipe'],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )

    // Customise report header (aCaMEL logo)
    CUSTOMIZE_REPORT( MULTIQC.out.report.map { _meta, report -> report } )

    emit:
    multiqc_report = CUSTOMIZE_REPORT.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
