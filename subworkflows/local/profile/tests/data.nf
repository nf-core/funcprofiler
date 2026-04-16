Adef Samplesheet(){
    return [      [
                    [
                        id: '2612',  // or could be '2612_ERR5766176' depending on schema
                        sample: '2612',
                        run_accession: 'ERR5766176',
                        instrument_platform: 'ILLUMINA',
                        single_end: false
                    ],
                    [
                        file('https://raw.githubusercontent.com/nf-core/test-datasets/taxprofiler/data/fastq/ERX5474932_ERR5766176_1.fastq.gz'),
                        file('https://raw.githubusercontent.com/nf-core/test-datasets/taxprofiler/data/fastq/ERX5474932_ERR5766176_2.fastq.gz')
                    ]
                ],
                // Second entry: sample 2612, run ERR5766176_B
                [
                    [
                        id: '2612',  // or '2612_ERR5766176_B'
                        sample: '2612',
                        run_accession: 'ERR5766176_B',
                        instrument_platform: 'ILLUMINA',
                        single_end: false
                    ],
                    [
                        file('https://raw.githubusercontent.com/nf-core/test-datasets/taxprofiler/data/fastq/ERX5474932_ERR5766176_B_1.fastq.gz'),
                        file('https://raw.githubusercontent.com/nf-core/test-datasets/taxprofiler/data/fastq/ERX5474932_ERR5766176_B_2.fastq.gz')
                    ]
                ],
                // Third entry: sample minigut, run 1
                [
                    [
                        id: 'minigut',  // or 'minigut_1'
                        sample: 'minigut',
                        run_accession: '1',
                        instrument_platform: 'ILLUMINA',
                        single_end: false
                    ],
                    [
                        file('https://github.com/nf-core/test-datasets/raw/mag/test_data/test_minigut_R1.fastq.gz'),
                        file('https://github.com/nf-core/test-datasets/raw/mag/test_data/test_minigut_R2.fastq.gz')
                    ]
                ]]
}

def DatabaseSheet() {
    return [
	[
        [
                        id: 'humann_v3_demo_v3_humann_nucleotide',  // typical composite ID
                        tool: 'humann_v3',
                        db_name: 'demo_v3',
                        db_entity: 'humann_nucleotide',
                        db_params: ''
                    ],
                    file('https://github.com/nickp60/test-datasets/raw/refs/heads/funcprofiler/data/database/humann/v3/chocophlan_nfDEMO.tar.gz')
                ],
                // humann_v3 - uniref_nfDEMO.tar.gz
                [
                    [
                        id: 'humann_v3_demo_v3_humann_protein',
                        tool: 'humann_v3',
                        db_name: 'demo_v3',
                        db_entity: 'humann_protein',
                        db_params: ''
                    ],
                    file('https://github.com/nickp60/test-datasets/raw/refs/heads/funcprofiler/data/database/humann/v3/uniref_nfDEMO.tar.gz')
                ],
                // humann_v3 - metaphlan4_database.tar.gz
                [
                    [
                        id: 'humann_v3_demo_v3_humann_metaphlan',
                        tool: 'humann_v3',
                        db_name: 'demo_v3',
                        db_entity: 'humann_metaphlan',
                        db_params: ''
                    ],
                    file('https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/delete_me/metaphlan4_database.tar.gz')
                ],
                // humann_v3 - utility_nfDEMO.tar.gz
                [
                    [
                        id: 'humann_v3_demo_v3_humann_utility',
                        tool: 'humann_v3',
                        db_name: 'demo_v3',
                        db_entity: 'humann_utility',
                        db_params: ''
                    ],
                    file('https://raw.githubusercontent.com/nf-core/test-datasets/funcprofiler/data/database/humann/v3/utility_nfDEMO.tar.gz')
                ],
                // fmhfunprofiler
                [
                    [
                        id: 'fmhfunprofiler_fmhfunprofiler1000',
                        tool: 'fmhfunprofiler',
                        db_name: 'fmhfunprofiler1000',
                        db_entity: '',
                        db_params: '11 1000'
                    ],
                    file('https://github.com/nickp60/test-datasets/raw/refs/heads/funcprofiler/data/database/fmhfunprofiler/KOs_sketched_scaled_1000_demo.sig.zip')
                ],
                // rgi
                [
                    [
                        id: 'rgi_4.0.1',
                        tool: 'rgi',
                        db_name: '4.0.1',
                        db_entity: '',
                        db_params: ''
                    ],
                    file('https://github.com/nickp60/test-datasets/raw/refs/heads/funcprofiler/data/database/rgi/broadstreet-v4.0.1.tar.bz2')
                ],
                // humann_v4 - chocophlan_nfDEMO.tar.gz
                [
                    [
                        id: 'humann_v4_demo_v4_humann_nucleotide',
                        tool: 'humann_v4',
                        db_name: 'demo_v4',
                        db_entity: 'humann_nucleotide',
                        db_params: ''
                    ],
                    file('https://github.com/nickp60/test-datasets/raw/refs/heads/funcprofiler/data/database/humann/v4/chocophlan_nfDEMO.tar.gz')
                ],
                // humann_v4 - uniref_nfDEMO.tar.gz
                [
                    [
                        id: 'humann_v4_demo_v4_humann_protein',
                        tool: 'humann_v4',
                        db_name: 'demo_v4',
                        db_entity: 'humann_protein',
                        db_params: ''
                    ],
                    file('https://github.com/nickp60/test-datasets/raw/refs/heads/funcprofiler/data/database/humann/v4/uniref_nfDEMO.tar.gz')
                ],
                // humann_v4 - utility_nfDEMO.tar.gz
                [
                    [
                        id: 'humann_v4_demo_v4_humann_utility',
                        tool: 'humann_v4',
                        db_name: 'demo_v4',
                        db_entity: 'humann_utility',
                        db_params: ''
                    ],
                    file('https://github.com/nickp60/test-datasets/raw/refs/heads/funcprofiler/data/database/humann/v4/utility_nfDEMO.tar.gz')
                ],
                // humann_v4 - metaphlan_demo_for_humann4.tar.gz
                [
                    [
                        id: 'humann_v4_demo_v4_humann_metaphlan',
                        tool: 'humann_v4',
                        db_name: 'demo_v4',
                        db_entity: 'humann_metaphlan',
                        db_params: ''
                    ],
                    file('https://github.com/nickp60/test-datasets/raw/refs/heads/funcprofiler/data/database/metaphlan/metaphlan_demo_for_humann4.tar.gz')
                ],
                // mifaser
                [
                    [
                        id: 'mifaser_GS-24-all',
                        tool: 'mifaser',
                        db_name: 'GS-24-all',
                        db_entity: '',
                        db_params: ''
                    ],
                    file('https://github.com/nickp60/test-datasets/raw/refs/heads/funcprofiler/data/database/mifaser/GS-24-all.tar.gz')
                ],
                // eggnogmapper - proteome.dmnd
                [
                    [
                        id: 'eggnogmapper_demo_eggnogmapper_db',
                        tool: 'eggnogmapper',
                        db_name: 'demo',
                        db_entity: 'eggnogmapper_db',
                        db_params: ''
                    ],
                    file('https://github.com/nickp60/test-datasets/raw/refs/heads/funcprofiler/data/database/eggnog-mapper/proteome.dmnd')
                ],
                // eggnogmapper - eggnog.db
                [
                    [
                        id: 'eggnogmapper_demo_eggnogmapper_data_dir',
                        tool: 'eggnogmapper',
                        db_name: 'demo',
                        db_entity: 'eggnogmapper_data_dir',
                        db_params: ''
                    ],
                    file('https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/delete_me/eggnogmapper/eggnog.db')
                ],
                // diamond - proteome.dmnd
                [
                    [
                        id: 'diamond_demo_eggnogmapper_db',
                        tool: 'diamond',
                        db_name: 'demo',
                        db_entity: 'eggnogmapper_db',
                        db_params: ''
                    ],
                    file('https://github.com/nickp60/test-datasets/raw/refs/heads/funcprofiler/data/database/eggnog-mapper/proteome.dmnd')
	]
    ]

}
