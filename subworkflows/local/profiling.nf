//
// Run profiling
//

include { HUMANN_HUMANN                                 } from '../../modules/local/humann/humann/main'
include { FMHFUNPROFILER                                } from '../../modules/local/fmhfunprofiler/main'
include { CAT_FASTQ                                     } from '../../modules/nf-core/cat/fastq/main'
//include { METAPHLAN_METAPHLAN                           } from '../../modules/nf-core/metaphlan/metaphlan/main'


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
def combineProfilesWithDatabase(ch_profile, ch_database) {

return ch_profile
    .map { meta, profile -> [meta.db_name, meta, profile] }
    .combine(ch_database, by: 0)
    .multiMap {
        key, meta, profile, db_meta, db ->
            profile: [meta, profile]
            db: db
    }
}

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
    ch_dbs = databases
        .map{
            meta_db, db ->
            [ [meta_db.db_type.split(";")].flatten(), meta_db, db]
        }
        .transpose(by: 0)
        .map{
            type, meta_db, db ->
            [[type: type], meta_db.subMap(meta_db.keySet() - 'db_type') + [type: type], db]
        }

    ch_input_for_profiling = reads
        .map{
            meta, reads ->
            [[type: meta.type], meta, reads]
        }
        .combine(ch_dbs, by: 0)
        .map{
            db_type, meta, reads, db_meta, db ->
            [ meta, reads, db_meta, db ]
        }
        .branch { meta, reads, db_meta, db ->
            humann:         db_meta.tool == 'rgi'
            unknown:    true
        }
    if ( params.run_rgi ) {

        // Generate profile
        //ch_versions            = ch_versions.mix( FMHFUNPROFILER.out.versions.first() )
       // ch_raw_profiles        = ch_raw_profiles.mix( FMHFUNPROFILER.out.ko )
	//  ch_multiqc_files       = ch_multiqc_files.mix( CENTRIFUGE_KREPORT.out.kreport )

    }

    emit:
    profiles        = ch_raw_profiles    // channel: [ val(meta), [ reads ] ] - should be text files or biom
    versions        = ch_versions          // channel: [ versions.yml ]
    mqc             = ch_multiqc_files
}


workflow PROFILING_CONCAT {
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
    ch_dbs = databases
        .map{
            meta_db, db ->
            [ [meta_db.db_type.split(";")].flatten(), meta_db, db]
        }
        .transpose(by: 0)
        .map{
            type, meta_db, db ->
            [[type: type], meta_db.subMap(meta_db.keySet() - 'db_type') + [type: type], db]
        }

    // Join short and long reads with their corresponding short/long database
    // Note that for not-specified `short;long`, it will match with the database.
    // E.g. if there is no 'long' reads the above generated 'long' database channel element
    //  will have nothing to join to and will be discarded
    // Final output [DUMP: reads_plus_db] [['id':'2612', 'run_accession':'combined', 'instrument_platform':'ILLUMINA', 'single_end':false, 'is_fasta':false, 'type':'short'], <reads_path>/2612.merged.fastq.gz, ['tool':'malt', 'db_name':'malt95', 'db_params':'"-id 90"', 'type':'short'], <db_path>/malt95]
    ch_input_for_profiling = reads
        .map{
            meta, reads ->
            [[type: meta.type], meta, reads]
        }
        .combine(ch_dbs, by: 0)
        .map{
            db_type, meta, reads, db_meta, db ->
            [ meta, reads, db_meta, db ]
        }
        .branch { meta, reads, db_meta, db ->
            humann:         db_meta.tool == 'humann'
            fmhfunprofiler: db_meta.tool == 'fmhfunprofiler'
            unknown:    true
        }
    /*
        PREPARE PROFILER INPUT CHANNELS & RUN PROFILING
    */

    // Each tool as a slightly different input structure and generally separate
    // input channels for reads vs databases. We restructure the channel tuple
    // for each tool and make liberal use of multiMap to keep reads/databases
    // channel element order in sync with each other
    if ( params.run_fmhfunprofiler ) {
	// stolen logic from taxprofiler.
        ch_input_for_fmhfunprofiler =  ch_input_for_profiling.fmhfunprofiler
            .multiMap {
                meta, reads, db_meta, db ->
		def new_meta = meta +  db_meta
		new_meta.db_params = db_meta["db_params"]

                reads: [ new_meta,  [reads].flatten() ]
                db: db
	    }
//	println(ch_input_for_fmhfunprofiler.reads.view())
        FMHFUNPROFILER ( ch_input_for_fmhfunprofiler.reads, ch_input_for_fmhfunprofiler.db )

        // Generate profile
        ch_versions            = ch_versions.mix( FMHFUNPROFILER.out.versions.first() )
        ch_raw_profiles        = ch_raw_profiles.mix( FMHFUNPROFILER.out.ko )
	//  ch_multiqc_files       = ch_multiqc_files.mix( CENTRIFUGE_KREPORT.out.kreport )

    }
    if ( params.run_humann ) {
	def humann_dbs_raw = ch_dbs
	    .map{
		type, db_meta, db ->
		def newmeta = db_meta - db_meta.subMap('type')
		[newmeta, db]
	    }
	    .unique()
	    .filter { db_meta, db -> db_meta.tool == "humann" | db_meta.tool == "metaphlan" }
	humann_dbs_raw = humann_dbs_raw
	    .branch {
                db_meta, db ->
                pangenome: db_meta.tool == "metaphlan"
                // trying to avoid having to do this in bash, cause then its trickier to log the version
		     def indexname = file("${db}").listFiles().find { it.name.contains("rev.1.bt2") }.name.replaceAll(/\.rev\.1\.bt2.*/, "")
                     return [db_meta, db, indexname].unique()
		nucleotide: db_meta.tool == "humann" && db_meta.db_name == "nucleotide"
                    return [db_meta, db].unique()
		protein: db_meta.tool == "humann" && db_meta.db_name == "protein"
                    return [db_meta, db].unique()

            }

        ch_input_for_humann =  ch_input_for_profiling.humann
            .map {
                meta, reads, db_meta, db ->

                [ meta,  [reads].flatten() ]
	    }
	    .unique()
	println(humann_dbs_raw.pangenome.class)
        HUMANN_HUMANN ( ch_input_for_humann, humann_dbs_raw.pangenome, humann_dbs_raw.nucleotide, humann_dbs_raw.protein)

        // Generate profile
        ch_versions            = ch_versions.mix( HUMANN_HUMANN.out.versions.first() )
        ch_raw_profiles        = ch_raw_profiles.mix( HUMANN_HUMANN.out.pathabundance )
	    .mix( HUMANN_HUMANN.out.genefamilies )
	    .mix( HUMANN_HUMANN.out.pathcoverage )
	//  ch_multiqc_files       = ch_multiqc_files.mix( CENTRIFUGE_KREPORT.out.kreport )

    }

    emit:
    profiles        = ch_raw_profiles    // channel: [ val(meta), [ reads ] ] - should be text files or biom
    versions        = ch_versions          // channel: [ versions.yml ]
    mqc             = ch_multiqc_files
//    classifications = ch_raw_classifications
//  motus_version   = params.run_motus ? MOTUS_PROFILE.out.versions.first() : Channel.empty()
}
