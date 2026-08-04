//
// Run profiling
//

include { MIFASER } from '../../../modules/nf-core/mifaser/main'
include { HUMANN3_HUMANN } from '../../../modules/nf-core/humann3/humann/main'
include { HUMANN4 } from '../../../modules/local/humann4/humann/main'
include { HUMANN3_REGROUP } from '../../../modules/nf-core/humann3/regroup/main'
include { HUMANN4_REGROUP } from '../../../modules/local/humann4/regroup/main'
include { FMHFUNPROFILER } from '../../../modules/nf-core/fmhfunprofiler/main'
include {
    METAPHLAN_METAPHLAN as MPAHUMANN3 ;
    METAPHLAN_METAPHLAN as MPAHUMANN4
} from '../../../modules/nf-core/metaphlan/metaphlan/main'
include { DIAMOND_BLASTX } from '../../../modules/nf-core/diamond/blastx/main'
include { RGI_BWT } from '../../../modules/nf-core/rgi/bwt/main'
include { RGI_CARDANNOTATION } from '../../../modules/nf-core/rgi/cardannotation/main'
include { EGGNOGMAPPER } from '../../../modules/nf-core/eggnogmapper/main'
include { SEQKIT_FQ2FA } from '../../../modules/nf-core/seqkit/fq2fa/main'
include { GUNZIP } from '../../../modules/nf-core/gunzip/main'

// Custom Functions

/**
* Combine profiles with their original database, then separate into two channels.
*
* The channel elements are assumed to be tuples one of [ meta, profile ], and the
* database to be of [db_key, meta, database_file].
*
* @param ch_profile A channel containing a meta and the profiling report of a given profiler
* @param ch_database A channel containing a key, the database meta, and the database file/folders itself
* @return A multiMap'ed output channel with two sub channels, one with the profile and the other with the db
*/
def sanitizeId(str) {
    return str
        .toString()
        // underscores to hyphens, spaces to hyphens, drop special chars, collapse hyphens
        .replaceAll(/_/, '-')
        .replaceAll(/\s+/, '-')
        .replaceAll(/[^\w\-.]/, '')
        .replaceAll(/-+/, '-')
}
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
        .flatMap { meta_db, file_list ->
            // Flatten: emit one tuple per file object
            file_list.collect { file_obj ->
                // Merge the file object's db_entity into the metadata
                def meta_with_entity = meta_db + [db_entity: file_obj.db_entity]
                [meta_with_entity, file_obj]
            }
        }
        .filter { meta_db, file ->
            meta_db.tool == tool_name
        }
        .map { meta_db, file ->
            // Create grouping key: [tool, db_name, db_params]
            def group_key = [meta_db.tool, meta_db.db_name ?: '', meta_db.db_params ?: '']
            [group_key, meta_db, file]
        }
        // Group all files for same tool+db_name+db_params
        .groupTuple()
        .map { group_key, meta_db_list, files ->
            def tool = group_key[0]
            def db_name = group_key[1]
            def db_params = group_key[2]

            // Convert files list to Map keyed by db_entity for deterministic snapshots
            // Map structure: entity_name -> db_path (entity is already in the key)
            def files_map = [:]
            [meta_db_list, files]
                .transpose()
                .each { meta_db, file ->
                    // Store only the path
                    files_map[meta_db.db_entity] = file.db_path
                }

            // Create consolidated metadata with db_entities as a Set
            def meta_db_grouped = [id: sanitizeId("${tool}--${db_name}--${db_params}"), tool: tool, db_name: db_name, db_params: db_params, db_entities: files_map.keySet() as Set, num_files: files_map.size()]

            // Return files as map
            [meta_db_grouped, files_map.toSorted()]
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
            // Carry the database identity into the read meta so that ext.args, ext.prefix
            // and publishDir can key on it, as nf-core/taxprofiler does. Only a subset is
            // merged: meta_db also holds an id, which must not overwrite the sample id.
            reads: [it[0] + it[2].subMap('tool', 'db_name', 'db_params'), it[1]]
            db: [it[2], it[3]]
        }
    return result
}

def getDbPath(groupeddb, entity = 'main', asTuple = false) {
    // Extract the relevant database file path by entity key from the files map
    def dbpath = groupeddb.map { meta_db, files_map ->
        // files_map is now a Map[entity -> db_path], so direct lookup
        if (!files_map.containsKey(entity)) {
            error("No entity '${entity}' file found in database ${meta_db.id}")
        }

        def db_path = files_map[entity]
        // Direct access to path

        if (asTuple) {
            return [meta_db, db_path]
        }
        else {
            return db_path
        }
    }
    return dbpath
}

workflow PROFILING {
    take:
    reads // [ [ meta ], [ reads ] ]
    reads_concat // [ [ meta ], [ reads ] ]
    databases // [ [ meta ], path ]

    main:
    // These are count tables
    ch_raw_profiles = channel.empty()

    /*
        COMBINE READS WITH POSSIBLE DATABASES
    */
    // Each tool as a slightly different input structure and generally separate
    // input channels for reads vs databases. We restructure the channel tuple
    // for each tool and make liberal use of multiMap to keep reads/databases
    // channel element order in sync with each other

    // PAIRED-END READ TOOLS
    ch_input_for_rgi = prepareInputs(reads, databases, 'rgi', false)
    ch_input_for_eggnogmapper = prepareInputs(reads_concat, databases, 'eggnogmapper', true)

    // CONCAT READ TOOLS
    ch_input_for_fmhfunprofiler = prepareInputs(reads_concat, databases, 'fmhfunprofiler', true)
    ch_input_for_diamond = prepareInputs(reads_concat, databases, 'diamond', true)
    ch_input_for_humann_v3 = prepareInputs(reads_concat, databases, 'humann_v3', true)
    ch_input_for_humann_v4 = prepareInputs(reads_concat, databases, 'humann_v4', true)
    ch_input_for_mifaser = prepareInputs(reads_concat, databases, 'mifaser', true)

    if (params.run_fmhfunprofiler) {
        // this tool needs the db_params at runtime, so it takes a [[meta], path] tuple instead of just a path
        getDbPath(ch_input_for_fmhfunprofiler.db, "main", true)
            .multiMap { db_meta, db_path ->
                def args = db_meta.db_params.split(" ")

                if (args.size() != 2) {
                    throw new IllegalArgumentException("fmh-funcprofiler's db_params must be configured with 2 ints (kmer and sketch db args) , but got ${args.size()}:  ${db_meta.db_params}")
                }
                db_path: db_path
                kmer: args[0]
                sketch: args[1]
            }
            .set { fmh_db }
        FMHFUNPROFILER(
            ch_input_for_fmhfunprofiler.reads,
            fmh_db.db_path,
            fmh_db.kmer,
            fmh_db.sketch,
        )
        ch_raw_profiles = ch_raw_profiles.mix(FMHFUNPROFILER.out.csv)
    }
    if (params.run_mifaser) {
        ch_input_for_mifaser = prepareInputs(reads_concat, databases, 'mifaser', true)
        MIFASER(ch_input_for_mifaser.reads, getDbPath(ch_input_for_mifaser.db, 'main'))
        ch_raw_profiles = ch_raw_profiles.mix(MIFASER.out.ec_counts)
    }

    if (params.run_humann_v3) {
        MPAHUMANN3(
            ch_input_for_humann_v3.reads,
            getDbPath(ch_input_for_humann_v3.db, 'humann_metaphlan'),
            false,
        )
        // JOIN the original reads with the profile output
        ch_humann3_input = ch_input_for_humann_v3.reads.join(MPAHUMANN3.out.profile, by: 0)
        // Join on meta map
        HUMANN3_HUMANN(
            ch_humann3_input.map { it -> [it[0], it[1]] },
            ch_humann3_input.map { it -> [it[0], it[2]] },
            getDbPath(ch_input_for_humann_v3.db, 'humann_nucleotide'),
            getDbPath(ch_input_for_humann_v3.db, 'humann_protein'),
            getDbPath(ch_input_for_humann_v3.db, 'humann_utility'),
        )
        HUMANN3_REGROUP(HUMANN3_HUMANN.out.genefamilies, "uniref90_level4ec", getDbPath(ch_input_for_humann_v3.db, 'humann_utility'))
        ch_raw_profiles = ch_raw_profiles.mix(MPAHUMANN3.out.profile)
        ch_raw_profiles = ch_raw_profiles
            .mix(HUMANN3_HUMANN.out.pathabundance)
            .mix(HUMANN3_HUMANN.out.genefamilies)
            .mix(HUMANN3_HUMANN.out.pathcoverage)
	    .mix(HUMANN3_REGROUP.out.regroup)
    }
    if (params.run_humann_v4) {
        MPAHUMANN4(
            ch_input_for_humann_v4.reads,
            getDbPath(ch_input_for_humann_v4.db, 'humann_metaphlan'),
            false,
        )
        ch_humann4_input = ch_input_for_humann_v4.reads.join(MPAHUMANN4.out.profile, by: 0)
        // Join on meta map

        HUMANN4(
            ch_humann4_input.map { it -> [it[0], it[1]] },
            ch_humann4_input.map { it -> [it[0], it[2]] },
            getDbPath(ch_input_for_humann_v4.db, 'humann_nucleotide'),
            getDbPath(ch_input_for_humann_v4.db, 'humann_protein'),
            getDbPath(ch_input_for_humann_v4.db, 'humann_utility'),
        )
        HUMANN4_REGROUP(HUMANN4.out.genefamilies, "uniclust90_level4ec", getDbPath(ch_input_for_humann_v4.db, 'humann_utility'))
        ch_raw_profiles = ch_raw_profiles
            .mix(HUMANN4.out.pathabundance)
            .mix(HUMANN4.out.genefamilies)
            .mix(HUMANN4.out.reactions)
	    .mix(HUMANN4_REGROUP.out.regroup)
    }

    if (params.run_diamond) {
        // 'txt' selects --outfmt 6 (tabular alignments). Do not use 'tsv': that is
        // --outfmt 102, DIAMOND's taxonomic classification format, which requires a
        // database built with --taxonmap/--taxonnodes and reports taxa rather than hits.
        DIAMOND_BLASTX(ch_input_for_diamond.reads, getDbPath(ch_input_for_diamond.db, "main", true), 'txt', '')
        ch_raw_profiles = ch_raw_profiles.mix(DIAMOND_BLASTX.out.txt)
    }

    if (params.run_rgi) {
        RGI_CARDANNOTATION(getDbPath(ch_input_for_rgi.db, "main"))
        RGI_BWT(ch_input_for_rgi.reads, RGI_CARDANNOTATION.out.db, [])
        ch_raw_profiles = ch_raw_profiles.mix(RGI_BWT.out.tsv)
    }
    if (params.run_eggnogmapper) {
        SEQKIT_FQ2FA(ch_input_for_eggnogmapper.reads)
        GUNZIP(SEQKIT_FQ2FA.out.fasta)
        // EGGNOGMAPPER takes the search database as [ search_mode, db ]: the mode picks the
        // flag emapper.py is given, and 'diamond' is what a .dmnd database needs.
        EGGNOGMAPPER(
            GUNZIP.out.gunzip,
            getDbPath(ch_input_for_eggnogmapper.db, "eggnogmapper_db").map { db -> ['diamond', db] },
            getDbPath(ch_input_for_eggnogmapper.db, "eggnogmapper_data_dir"),
        )
        ch_raw_profiles = ch_raw_profiles.mix(EGGNOGMAPPER.out.annotations)
    }

    emit:
    profiles = ch_raw_profiles // channel: [ val(meta), path(profile) ]
    // Software versions are published to the `versions` topic by each module
}


// due to https://github.com/askimed/nf-test/issues/309
workflow TEST_PREPAREINPUTS_WRAPPER {
    take:
    reads
    databases
    tool_name
    singleFqTool

    main:
    testresult = prepareInputs(reads, databases, tool_name, singleFqTool)

    emit:
    reads = testresult.reads
    db = testresult.db
}
