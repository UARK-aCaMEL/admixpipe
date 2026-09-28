process POP_SUMMARY {
    label 'process_single'
    tag "$meta.id"

    container "docker.io/tkchafin/plotly:1.1"

    input:
        tuple val(meta), path(snpio_report_data)
        path(header)

    output:
        path("pop_summary_mqc.json"), emit: summary_txt
        path("versions.yml"), emit: versions

    script:

    """
    echo "🔍 Finding input files..."
    miss1=\$(find -L ${snpio_report_data} -type f -name 'multiqc_population_missingness_table.txt' | head -n1)
    miss2=\$(find -L ${snpio_report_data} -type f -name 'multiqc_population_missingness-2_table.txt' | head -n1)

    echo "📊 Generating population summary..."
    pop_summary.py \\
        --miss-pre \$miss1 \\
        --miss-post \$miss2 \\
        --header ${header} \\
        --output pop_summary_mqc.json

    pandas_version=\$(python3 -c 'import pandas; print(pandas.__version__)')
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pandas: \${pandas_version}
    END_VERSIONS
    """
}
