//
// Prepare the databases for profiling.
//
// Takes the validated database sheet from PIPELINE_INITIALISATION, drops the rows belonging to
// profilers that are not enabled, decompresses the TAR archives among the rest, and groups the
// remaining paths by [ tool, db_name, db_params ] into a Map of `db_entity -> path`. Tools that
// take a single database leave `db_entity` empty in the sheet and are stored under 'main'.
//
include { UNTAR } from '../../../modules/nf-core/untar/main'

workflow DBPREP {
    take:
    databases

    main:

    // Validate and decompress databases
    ch_dbs_for_untar = databases.branch { db_meta, db_path ->
        untar: db_path.name.endsWith(".tar.gz") | db_path.name.endsWith(".tar.bz2") | db_path.name.endsWith(".tar") | db_path.name.endsWith(".tar.xz")
        skip: true
    }
    // Filter the channel to untar only those databases for tools that are selected to be run by the user.
    // Also, to ensure only untar once per file, group together all databases of one file
    ch_inputdb_untar = ch_dbs_for_untar.untar
        .filter { db_meta, db_path ->
            params["run_${db_meta.tool}"]
        }
        .groupTuple(by: 1)
        .map { meta, dbfile ->
            def new_meta = ['id': dbfile.baseName] + ['meta': meta]
            [new_meta, dbfile]
        }

    // Untar the databases
    UNTAR(ch_inputdb_untar)
    // Spread out the untarred and shared databases
    ch_outputdb_from_untar = UNTAR.out.untar
        .map { meta, db ->
            [meta.meta, db]
        }
        .transpose(by: 0)

    ch_semifinal_dbs = ch_dbs_for_untar.skip
        .mix(ch_outputdb_from_untar)
        .map { db_meta, db ->
            def corrected_db_params = db_meta.db_params ? [db_params: db_meta.db_params] : [db_params: '-']
            [db_meta + corrected_db_params, db]
        }

    ch_grouped_dbs = ch_semifinal_dbs
        .map { meta, path ->
            def entity = meta.db_entity ?: 'main'
            [[tool: meta.tool, db_name: meta.db_name, db_params: meta.db_params], [entity, path]]
        }
        .groupTuple()
        .map { groupKey, groupTuples ->
            def grouped_dbs = groupTuples.collect { tuple ->
                [
                    db_entity: tuple[0],
                    db_path: tuple[1],
                ]
            }
            return [groupKey, grouped_dbs]
        }

    emit:
    dbs = ch_grouped_dbs
}
