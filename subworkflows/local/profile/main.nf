//
// Run profiling
//

include { MIFASER                                       } from '../../../modules/local/mifaser/main'
include { HUMANN3; HUMANN4                              } from '../../../modules/local/humann/humann/main'
include { HUMANN3_REGROUP;HUMANN4_REGROUP               } from '../../../modules/local/humann/regroup/main'
include { FMHFUNPROFILER                                } from '../../../modules/local/fmhfunprofiler/main'
include { METAPHLAN_METAPHLAN as MPAHUMANN3;
          METAPHLAN_METAPHLAN as MPAHUMANN4             } from '../../../modules/nf-core/metaphlan/metaphlan/main'
include { CONCAT_ALL                                    } from '../../../subworkflows/local/concatall'
include { DIAMOND_BLASTX                                } from '../../../modules/nf-core/diamond/blastx/main'
include { RGI_BWT                                       } from '../../../modules/nf-core/rgi/bwt/main'
include { EGGNOGMAPPER                                  } from '../../../modules/nf-core/eggnogmapper/main'
include { SEQKIT_FQ2FA                                  } from '../../../modules/nf-core/seqkit/fq2fa/main'
include { GUNZIP                                        } from '../../../modules/nf-core/gunzip/main'

// Custom Functions

/**
* Combine profiles with their original database, then separate into two channels.
*
* The channel elements are assumed to be tuples one of [ meta, profile ], and the
* database to be of [db_key, meta, database_file].
*
* @param ch_profile A channel containing a meta and the profilign report of a given profiler
* @param ch_database A channel containing a key, the database meta, and the database file/folders itself
* @return A multiMap'ed output channel with two sub channels, one with the profile and the other with the db
*/
def prepareInputs(pairedreads, databases, tool_name, singleFqTool = false) {
    /*
        COMBINE READS WITH DATABASES - GROUPED BY TOOL, VERSION, AND PARAMS

        Input:
        - pairedreads: channel of [meta, [reads]]
        - databases: channel of [meta_db, file]
        - tool_name: string - filter databases to only this tool (e.g., 'humann_v3', 'rgi')
        - singleFqTool: boolean - if true, reads need concatenation for PE samples

        Output:
        - channel of [meta_sample, reads, meta_db_grouped, db_files_map]
          where each sample has entries for the specified tool
    */
    // Step 1: Filter databases to only the requested tool, then group by db_name and db_params
    def ch_dbs_grouped = databases
	.view()
    .flatMap { meta_db, file_list ->
        // Flatten: emit one tuple per file object
        file_list.collect { file_obj ->
            // Merge the file object's db_entity into the metadata
		def meta_with_entity = meta_db + [db_entity: file_obj.db_entity]
		println(meta_with_entity)
            [meta_with_entity, file_obj]
        }
    }
    .filter { meta_db, file ->
        meta_db.tool == tool_name
    }
    .map { meta_db, file ->
        // Create grouping key: [tool, db_name, db_params]
        def group_key = [
            meta_db.tool,
            meta_db.db_name ?: '',
            meta_db.db_params ?: ''
        ]
        [group_key, meta_db, file]
    }
    .groupTuple()  // Group all files for same tool+db_name+db_params
    .map { group_key, meta_db_list, files ->
        def tool = group_key[0]
        def db_name = group_key[1]
        def db_params = group_key[2]

        // Create consolidated metadata
        def meta_db_grouped = [
            tool: tool,
            db_name: db_name,
            db_params: db_params,
            db_entities: meta_db_list.collect { it.db_entity },
            num_files: files.size(),
            id: "${tool}_${db_name}_${db_params}".replaceAll(/\s+/, '_')
        ]

        // Return files as list
        [meta_db_grouped, files]
	}
    // Step 2: Combine reads with ALL grouped databases (cartesian product)
    // Each sample will get one entry per unique db_name+db_params combination for this tool
    def reads_with_dbs = pairedreads
        .combine(ch_dbs_grouped)
        .map { meta_sample, reads, meta_db, db_files_map ->
            // Flatten reads to ensure consistent list format
            def flat_reads = [reads].flatten()

            // Return: [meta_sample, reads_list, meta_db, db_files_map]
            [meta_sample, flat_reads, meta_db, db_files_map]
        }

    // Step 3: Validate and add metadata based on tool type
    def result = reads_with_dbs
            .map { meta, reads, db_meta, db_files ->
                def expected = meta.single_end | singleFqTool ? 1 : 2
                if (reads.size() != expected) {
                error("PE-aware tool (${!singleFqTool})  '${db_meta.tool}': expected ${expected} read file(s) for sample ${meta.id} (single_end=${meta.single_end}), got ${reads.size()}")
                }
                [meta, reads, db_meta, db_files]
        }
	.multiMap { it ->
            reads: [it[0] , it[1]]
            db: [ it[2], it[3]]
        }
    return result

}

def getDbPath(groupeddb, entity='main'){
    // this extracts the relevant
    def dbpath = groupeddb
        .map { meta_db, file_list ->
            def matching_files = file_list
		.findAll { f -> f.db_entity == entity }
		.collect { f -> f.db_path }
            if (matching_files.size() == 0) {
                error("No entity '${entity}' file found in database ${meta_db.id}")
            }

            if (matching_files.size() > 1) {
                error("More than one entity '${entity}' file found in database ${meta_db.id}")
            }

            matching_files[0]
        }
    return dbpath
}



workflow PROFILING {
    take:
    reads         // [ [ meta ], [ reads ] ]
    reads_concat  // [ [ meta ], [ reads ] ]
    databases     // [ [ meta ], path ]

    main:
    ch_versions             = Channel.empty()
    ch_multiqc_files        = Channel.empty()
    ch_raw_profiles         = Channel.empty() // These are count tables

    /*
        COMBINE READS WITH POSSIBLE DATABASES
    */
    /*
        PREPARE PROFILER INPUT CHANNELS & RUN PROFILING
    */
    // Each tool as a slightly different input structure and generally separate
    // input channels for reads vs databases. We restructure the channel tuple
    // for each tool and make liberal use of multiMap to keep reads/databases
    // channel element order in sync with each other

    // PAIRED-END READ TOOLS
   rgi_inputs = prepareInputs(reads, databases, 'rgi', false)

    // CONCAT READ TOOLS
    ch_input_for_fmhfunprofiler = prepareInputs(reads_concat, databases, 'fmhfunprofiler', true)
    ch_input_for_humann_v3 = prepareInputs(reads_concat, databases, 'humann_v3', true)
    ch_input_for_humann_v4 = prepareInputs(reads_concat, databases, 'humann_v4', true)
    ch_input_for_mifaser = prepareInputs(reads_concat, databases, 'mifaser', true)



    if ( params.run_fmhfunprofiler ) {
         FMHFUNPROFILER ( ch_input_for_fmhfunprofiler.reads, ch_input_for_fmhfunprofiler.db)
         ch_raw_profiles        = ch_raw_profiles.mix( FMHFUNPROFILER.out.ko )
    }
    if ( params.run_mifaser ) {
        ch_input_for_mifaser =  prepareInputs(reads_concat, databases, 'mifaser', true)
        MIFASER ( ch_input_for_mifaser.reads, ch_input_for_mifaser.db)
        ch_raw_profiles        = ch_raw_profiles.mix( MIFASER.out.ec_counts )
    }

    if ( params.run_humann_v3 ) {
	// ch_input_for_humann =  ch_input_for_humann_v3.reads
	//     .multiMap {
	// 	meta, reads, db_meta, db ->
	// 	def new_meta = meta +  db_meta
	// 	def flat_reads = [reads].flatten()
	// 	if ( flat_reads.size() != 1 ) {
	// 	    error("humann_v3 requires exactly one (concatenated) input FASTQ, got ${flat_reads.size()} files for sample ${meta.id}")
	// 	}
	// 	reads: [ new_meta, flat_reads ]
	// 	mpa_db: db.findAll { it.db_entity == "humann_metaphlan" }.first().db_path
	// 	nuc_db: db.findAll { it.db_entity == "humann_nucleotide" }.first().db_path
	// 	prot_db: db.findAll { it.db_entity == "humann_protein" }.first().db_path
	// 	util_db: db.findAll { it.db_entity == "humann_utility" }.first().db_path
	//     }
	//if (params.run_humann && !input.mpa_profile){
	if (true){
            MPAHUMANN3 (
		ch_input_for_humann_v3.reads,
		getDbPath(ch_input_for_humann_v3.db, 'humann_metaphlan'),false
	    )
            HUMANN3 (
		ch_input_for_humann_v3.reads,
		MPAHUMANN3.out.profile,
		getDbPath(ch_input_for_humann_v3.db, 'humann_nucleotide'),
		getDbPath(ch_input_for_humann_v3.db, 'humann_protein'),
		getDbPath(ch_input_for_humann_v3.db, 'humann_utility'),
	    )
	    HUMANN3_REGROUP(HUMANN3.out.genefamilies, "uniref90_level4ec", getDbPath(ch_input_for_humann_v3.db, 'humann_utility'))
	} else {
	    println("not enabled")
	    // HUMANN_HUMANN ( ch_input_for_humann, ch_input_for_humann.metaphlan_profile , humann_dbs_raw.nucleotide, humann_dbs_raw.protein)
	}
        //ch_versions        = ch_versions.mix( MPAHUMANN3.out.versions.first() ) // TODO: update to topic once upstream is ready
        ch_raw_profiles    = ch_raw_profiles.mix( MPAHUMANN3.out.profile )
        //ch_versions            = ch_versions.mix( HUMANN3.out.versions_humann.first() )
        ch_raw_profiles        = ch_raw_profiles.mix( HUMANN3.out.pathabundance )
	    .mix( HUMANN3.out.genefamilies )
	    .mix( HUMANN3.out.pathcoverage )
    }
    // if ( params.run_humann_v4 ) {
    // 	ch_input_for_humann4 =  ch_merged_input_for_profiling.humann_v4
    // 	    .multiMap {
    // 		meta, reads, db_meta, db ->
    // 		def new_meta = meta +  db_meta
    // 		//TODO add the params in
    // 		//		new_meta.db_params = Channel.fromList(db).map{ t -> t.db_params}.collect().flatten() //  [0]["db_params"]
    // 		def flat_reads = [reads].flatten()
    // 		if ( flat_reads.size() != 1 ) {
    // 		    error("humann_v4 requires exactly one (concatenated) input FASTQ, got ${flat_reads.size()} files for sample ${meta.id}")
    // 		}
    // 		reads: [ new_meta, flat_reads ]
    // 		mpa_db: db.findAll { it.db_entity == "humann_metaphlan" }.first().db_path
    // 		nuc_db: db.findAll { it.db_entity == "humann_nucleotide" }.first().db_path
    // 		prot_db: db.findAll { it.db_entity == "humann_protein" }.first().db_path
    // 		util_db: db.findAll { it.db_entity == "humann_utility" }.first().db_path
    // 	    }
    // 	//if (params.run_humann && !input.mpa_profile){
    // 	if (true){
    //         MPAHUMANN4 ( ch_input_for_humann4.reads, ch_input_for_humann4.mpa_db, false )
    //         HUMANN4 ( ch_input_for_humann4.reads, MPAHUMANN4.out.profile, ch_input_for_humann4.nuc_db, ch_input_for_humann4.prot_db, ch_input_for_humann4.util_db)
    // 	    HUMANN4_REGROUP(HUMANN4.out.genefamilies, "uniclust90_level4ec", ch_input_for_humann4.util_db)
    // 	} else {
    // 	    println("not enabled")
    // 	    // HUMANN_HUMANN ( ch_input_for_humann, ch_input_for_humann.metaphlan_profile , humann_dbs_raw.nucleotide, humann_dbs_raw.protein)
    // 	}
    //     //ch_versions            = ch_versions.mix( HUMANN4.out.versions_humann.first() )
    //     ch_raw_profiles        = ch_raw_profiles.mix( HUMANN4.out.pathabundance )
    // 	    .mix( HUMANN4.out.genefamilies )
    // 	    .mix( HUMANN4.out.reactions )
    // }

    // if ( params.run_diamond ) {
    //     ch_input_for_diamond = ch_merged_input_for_profiling.diamond
    //         .multiMap {
    //             meta, reads, db_meta, db ->
    //             def new_meta = meta + db_meta
    //             def flat_reads = [reads].flatten()
    //             if ( flat_reads.size() != 1 ) {
    //                 error("diamond blastx requires exactly one (concatenated) input FASTQ, got ${flat_reads.size()} files for sample ${meta.id}")
    //             }
    //             reads: [ new_meta, flat_reads[0] ]
    //             db:    [ db_meta, db[0].db_path ]
    //         }
    //     DIAMOND_BLASTX ( ch_input_for_diamond.reads, ch_input_for_diamond.db, 'tsv', '' )

    //     //ch_versions     = ch_versions.mix( DIAMOND_BLASTX.out.versions.first() ) // TODO swap for topic once upstream is ready
    //     ch_raw_profiles = ch_raw_profiles.mix( DIAMOND_BLASTX.out.tsv )
    // }

    // if ( params.run_rgi ) {
    //     ch_input_for_rgi = ch_paired_input_for_profiling.rgi
    //         .multiMap {
    //             meta, reads, db_meta, db ->
    //             def new_meta = meta + db_meta
    //             reads: [ new_meta, [reads].flatten() ]
    //             card:  db[0].db_path
    //         }
    //     RGI_BWT( ch_input_for_rgi.reads, ch_input_for_rgi.card, [] )

    //     //ch_versions     = ch_versions.mix( RGI_BWT.out.versions_rgi.first())
    //     ch_raw_profiles = ch_raw_profiles.mix( RGI_BWT.out.tsv )
    // }
    // if ( params.run_eggnogmapper ) {
    //     ch_input_for_eggnogmapper = ch_merged_input_for_profiling.eggnogmapper
    //         .multiMap {
    //             meta, reads, db_meta, db ->
    //             def new_meta = meta + db_meta
    //             def flat_reads = [reads].flatten()
    //             if ( flat_reads.size() != 1 ) {
    //                 error("eggnogmapper requires exactly one input FASTA, got ${flat_reads.size()} files for sample ${meta.id}")
    //             }
    //             fastq:    [ new_meta, flat_reads[0] ]
    //             search_db: db.findAll { it.db_entity == "eggnogmapper_db" }.first().db_path
    //             data_dir:  db.findAll { it.db_entity == "eggnogmapper_data_dir" }.first().db_path
    //         }
    // 	SEQKIT_FQ2FA(ch_input_for_eggnogmapper.fastq)
    // 	GUNZIP(SEQKIT_FQ2FA.out.fasta)
    //     EGGNOGMAPPER (
    //         GUNZIP.out.gunzip,
    //         ch_input_for_eggnogmapper.search_db.map { db -> [ 'diamond', db ] },
    //         ch_input_for_eggnogmapper.data_dir
    //     )

    //     //ch_versions     = ch_versions.mix( EGGNOGMAPPER.out.versions_eggnogmapper.first() )
    //     ch_raw_profiles = ch_raw_profiles.mix( EGGNOGMAPPER.out.annotations )

    // }

    emit:
    profiles        = ch_raw_profiles    // channel: [ val(meta), [ reads ] ] - should be text files or biom
    versions        = ch_versions          // channel: [ versions.yml ]
    mqc             = ch_multiqc_files
}


workflow TEST_PREPAREINPUTS_WRAPPER {
    // due to  https://github.com/askimed/nf-test/issues/309)
    take:
    reads
    databases
    tool_name
    singleFqTool

    main:
    testresult = prepareInputs(reads, databases, tool_name, singleFqTool)
    emit:
    reads = testresult.reads
    db    = testresult.db
}
