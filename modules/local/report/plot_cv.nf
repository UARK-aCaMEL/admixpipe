process PLOT_CV {
    tag "$meta.id"
    label 'process_single'

    container "docker.io/tkchafin/plotly:1.1"

    input:
        tuple val(meta), path(cv_file)
        tuple val(meta2), path(bestk_file)
        path(template)

    output:
        path("cvplot_mqc.html"), emit: cv_html
        path("versions.yml")   , emit: versions

    script:
    """
    bestk=\$(cat ${bestk_file})

    plot_cv.py \\
        ${cv_file} \\
        --bestk \$bestk \\
        --template ${template}

    plotly_version=\$(python3 -c 'import plotly; print(plotly.__version__)')

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        plotly: \${plotly_version}
    END_VERSIONS
    """
}
