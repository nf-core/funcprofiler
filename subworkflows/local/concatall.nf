include { CAT_FASTQ                                     } from '../../modules/nf-core/cat/fastq/main'


workflow CONCAT_ALL {
	take:
	ch_reads // [ [ meta ], [ reads ] ]

	main:
	ch_input_singlefq = ch_reads
		.map { meta, reads ->
			def meta_new = meta - meta.subMap('run_accession')
			meta_new["single_end"] = true
			[ meta_new, reads ]
		}
		.groupTuple()
		.map { meta, reads ->
			[ meta, reads.flatten().sort { it.name } ]
		}
		.branch { _meta, reads ->
			cat: reads.size() > 1
			skip: true
		}

	ch_input_reads_merged = CAT_FASTQ( ch_input_singlefq.cat ).reads
		.map { meta, reads -> [ meta, [reads].flatten() ] }
		.mix( ch_input_singlefq.skip )

	emit:
	ch_input_reads_merged
}
