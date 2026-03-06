//
// Run profiling
//

include { HUMANN3; HUMANN4                              } from '../../modules/local/humann/humann/main'
include { FMHFUNPROFILER                                } from '../../modules/local/fmhfunprofiler/main'
include { METAPHLAN_METAPHLAN as MPA_HUMANN3;
	 METAPHLAN_METAPHLAN as MPA_HUMANN4             } from '../../modules/nf-core/metaphlan/metaphlan/main'
include { CAT_FASTQ                                     } from '../../modules/nf-core/cat/fastq/main'
include { CONCAT_ALL                                    } from '../../subworkflows/local/concatall'
include { DIAMOND_BLASTX                                } from '../../modules/nf-core/diamond/blastx/main'


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

def prepareInputs(pairedreads, databases, singleFqTool=False){
    /*
        COMBINE READS WITH POSSIBLE DATABASES
    */

    // Separate default 'short;long' (when necessary) databases when short/long specified in database sheet
    // TODO: check combined dbs have same type
    ch_dbs = databases
        .map{
            tool_and_name, meta_db ->
	    def first_type = meta_db[0].db_type
            [ [first_type.split(";")].flatten(), tool_and_name, meta_db]
        }
        .transpose(by: 0)
        .map{
            type, meta_db, dblist ->
            [[type: type], meta_db.subMap(meta_db.keySet() - 'db_type') + [type: type], dblist]
        }

    reads_with_dbs = pairedreads
        .map{
            meta, reads ->
            [[type: meta.type], meta, reads]
        }
        .combine(ch_dbs, by: 0)
        .map{
            db_type, meta, reads, db_meta, db ->
            [ meta, reads, db_meta, db ]
        }
    if (singleFqTool){
        return reads_with_dbs
        .branch { meta, reads, db_meta, db ->
            humann_v3:      db_meta.tool == 'humann_v3'
            humann_v4:      db_meta.tool == 'humann_v4'
            fmhfunprofiler: db_meta.tool == 'fmhfunprofiler'
            diamond:        db_meta.tool == 'diamond'
            unknown:        true
        }
    } else {
        return reads_with_dbs
	    .branch { meta, reads, db_meta, db ->
		rgi:         db_meta.tool == 'rgi'
		unknown:    true
            }
    }
}
// def prepareMergedInputs(mergedreads, databases){
//         ch_dbs = databases
//         .map{
//             tool_and_name, meta_db ->
// 	    def first_type = meta_db[0].db_type
//             [ [first_type.split(";")].flatten(), tool_and_name, meta_db]
//         }
//         .transpose(by: 0).view()
//         .map{
//             type, meta_db, dblist ->
//             [[type: type], meta_db.subMap(meta_db.keySet() - 'db_type') + [type: type], dblist]
//         }


//     return mergedreads
//         .map{
//             meta, reads ->
//             [[type: meta.type], meta, reads]
//         }
//         .combine(ch_dbs, by: 0)
//         .map{
//             db_type, meta, reads, db_meta, db ->
//             [ meta, reads, db_meta, db ]
//         }
//         .branch { meta, reads, db_meta, db ->
//             humann:         db_meta.tool == 'humann'
//             fmhfunprofiler: db_meta.tool == 'fmhfunprofiler'
//             unknown:    true
//         }
// }





// def combineProfilesWithDatabase(ch_profile, ch_database) {

// return ch_profile
//     .map { meta, profile -> [meta.db_name, meta, profile] }
//     .combine(ch_database, by: 0)
//     .multiMap {
//         key, meta, profile, db_meta, db ->
//             profile: [meta, profile]
//             db: db
//     }
// }



workflow PROFILING {
    take:
    reads // [ [ meta ], [ reads ] ]
    databases // [ [ meta ], path ]

    main:
    ch_versions             = Channel.empty()
    ch_multiqc_files        = Channel.empty()
    ch_raw_profiles         = Channel.empty() // These are count tables

    /*
        COMBINE READS WITH POSSIBLE DATABASES
    */

    // Separate default 'short;long' (when necessary) databases when short/long specified in database sheet

    /*
        PREPARE PROFILER INPUT CHANNELS & RUN PROFILING
    */
    CONCAT_ALL(reads)
    ch_paired_input_for_profiling = prepareInputs(reads, databases, false)
    ch_merged_input_for_profiling = prepareInputs(CONCAT_ALL.out.ch_input_reads_merged, databases, true)
    // Each tool as a slightly different input structure and generally separate
    // input channels for reads vs databases. We restructure the channel tuple
    // for each tool and make liberal use of multiMap to keep reads/databases
    // channel element order in sync with each other
    if ( params.run_fmhfunprofiler ) {
	// stolen logic from taxprofiler.  except for undoing the mutliple-database maddness imposed earlier
        ch_input_for_fmhfunprofiler =  ch_merged_input_for_profiling.fmhfunprofiler
            .multiMap {
                meta, reads, db_meta, db ->
		def new_meta = meta +  db_meta
		new_meta.db_params = db[0]["db_params"]
                reads: [ new_meta,  [reads].flatten() ]
                db: db[0].db_path
	    }
        FMHFUNPROFILER ( ch_input_for_fmhfunprofiler.reads, ch_input_for_fmhfunprofiler.db )

        // Generate profile
        ch_versions            = ch_versions.mix( FMHFUNPROFILER.out.versions.first() )
        ch_raw_profiles        = ch_raw_profiles.mix( FMHFUNPROFILER.out.ko )
	//  ch_multiqc_files       = ch_multiqc_files.mix( CENTRIFUGE_KREPORT.out.kreport )

    }

    if ( params.run_humann_v3 ) {
	ch_input_for_humann =  ch_merged_input_for_profiling.humann_v3
    	    .multiMap {
		meta, reads, db_meta, db ->
		def new_meta = meta +  db_meta
		//TODO add the params in
		//		new_meta.db_params = Channel.fromList(db).map{ t -> t.db_params}.collect().flatten() //  [0]["db_params"]
		reads: [ new_meta,  [reads].flatten() ]
		mpa_db: db.findAll { it.db_entity == "humann_metaphlan" }.first().db_path
		nuc_db: db.findAll { it.db_entity == "humann_nucleotide" }.first().db_path
		prot_db: db.findAll { it.db_entity == "humann_protein" }.first().db_path
		util_db: db.findAll { it.db_entity == "humann_utility" }.first().db_path
	    }
	//if (params.run_humann && !input.mpa_profile){
	if (true){
            MPA_HUMANN3 ( ch_input_for_humann.reads, ch_input_for_humann.mpa_db, false )
            HUMANN3 ( ch_input_for_humann.reads, MPA_HUMANN3.out.profile, ch_input_for_humann.nuc_db, ch_input_for_humann.prot_db, ch_input_for_humann.util_db
	                     )
	} else {
	    println("not enabled")
	    // HUMANN_HUMANN ( ch_input_for_humann, ch_input_for_humann.metaphlan_profile , humann_dbs_raw.nucleotide, humann_dbs_raw.protein)
	}
        ch_versions        = ch_versions.mix( MPA_HUMANN3.out.versions.first() )
        ch_raw_profiles    = ch_raw_profiles.mix( MPA_HUMANN3.out.profile )
        ch_versions            = ch_versions.mix( HUMANN3.out.versions.first() )
        ch_raw_profiles        = ch_raw_profiles.mix( HUMANN3.out.pathabundance )
	    .mix( HUMANN3.out.genefamilies )
	    .mix( HUMANN3.out.pathcoverage )
    }
    if ( params.run_humann_v4 ) {
	ch_input_for_humann4 =  ch_merged_input_for_profiling.humann_v4
    	    .multiMap {
		meta, reads, db_meta, db ->
		def new_meta = meta +  db_meta
		//TODO add the params in
		//		new_meta.db_params = Channel.fromList(db).map{ t -> t.db_params}.collect().flatten() //  [0]["db_params"]
		reads: [ new_meta,  [reads].flatten() ]
		mpa_db: db.findAll { it.db_entity == "humann_metaphlan" }.first().db_path
		nuc_db: db.findAll { it.db_entity == "humann_nucleotide" }.first().db_path
		prot_db: db.findAll { it.db_entity == "humann_protein" }.first().db_path
		util_db: db.findAll { it.db_entity == "humann_utility" }.first().db_path
	    }
	//if (params.run_humann && !input.mpa_profile){
	if (true){
            MPA_HUMANN4 ( ch_input_for_humann4.reads, ch_input_for_humann4.mpa_db, false )
            HUMANN4 ( ch_input_for_humann4.reads, MPA_HUMANN4.out.profile, ch_input_for_humann4.nuc_db, ch_input_for_humann4.prot_db, ch_input_for_humann4.util_db,
	                     )
	} else {
	    println("not enabled")
	    // HUMANN_HUMANN ( ch_input_for_humann, ch_input_for_humann.metaphlan_profile , humann_dbs_raw.nucleotide, humann_dbs_raw.protein)
	}
        ch_versions            = ch_versions.mix( HUMANN4.out.versions.first() )
        ch_raw_profiles        = ch_raw_profiles.mix( HUMANN4.out.pathabundance )
	    .mix( HUMANN4.out.genefamilies )
	    .mix( HUMANN4.out.reactions )
    }

    if ( params.run_diamond ) {
        ch_input_for_diamond = ch_merged_input_for_profiling.diamond
            .multiMap {
                meta, reads, db_meta, db ->
                def new_meta = meta + db_meta
                def flat_reads = [reads].flatten()
                if ( flat_reads.size() != 1 ) {
                    error("diamond blastx requires exactly one (concatenated) input FASTQ, got ${flat_reads.size()} files for sample ${meta.id}")
                }
                reads: [ new_meta, flat_reads[0] ]
                db:    [ db_meta, db[0].db_path ]
            }
        DIAMOND_BLASTX ( ch_input_for_diamond.reads, ch_input_for_diamond.db, 'tsv', '' )

        ch_versions     = ch_versions.mix( DIAMOND_BLASTX.out.versions.first() )
        ch_raw_profiles = ch_raw_profiles.mix( DIAMOND_BLASTX.out.tsv )
    }

// 	//  ch_multiqc_files       = ch_multiqc_files.mix( CENTRIFUGE_KREPORT.out.kreport )

//     /////////////   PAIRED Inputs
//     if ( params.run_rgi ) {
// 	println("WIP")
//     }

    emit:
    profiles        = ch_raw_profiles    // channel: [ val(meta), [ reads ] ] - should be text files or biom
    versions        = ch_versions          // channel: [ versions.yml ]
    mqc             = ch_multiqc_files
//    classifications = ch_raw_classifications
//  motus_version   = params.run_motus ? MOTUS_PROFILE.out.versions.first() : Channel.empty()
}
