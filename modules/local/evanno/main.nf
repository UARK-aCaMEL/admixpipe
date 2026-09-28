process EVANNO {
    tag "$meta.id"
    label 'process_single'

    container 'docker.io/btmartin721/snpio:1.7.5'

    input:
        tuple val(meta), path(ll_file)

    output:
        tuple val(meta), path('evanno_metrics.tsv')  , emit: metrics
        tuple val("${task.process}"), val('python'), eval("python --version 2>&1 | sed 's/Python //'"), topic: versions, emit: versions_python

    script:
    """
    evanno.py \\
        ${ll_file} \\
        -o "evanno_metrics.tsv"
    """
}
