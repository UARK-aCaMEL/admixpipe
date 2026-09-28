process FILTER_SUMMARY {
    label 'process_single'
    tag "$meta.id"

    conda "conda-forge::gawk=5.1.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gawk:5.1.0' :
        'biocontainers/gawk:5.1.0' }"

    input:
        tuple val(meta), path(snpio_pre)
        path(template)

    output:
        path("sankey_mqc.html"), emit: sankey_html

    script:

    """
    html=\$(find -L ${snpio_pre} -type f -name 'filtering_results_sankey*.html' | head -n1)

    cat ${template} > sankey_mqc.html
    cat \$html >> sankey_mqc.html
    """
}
