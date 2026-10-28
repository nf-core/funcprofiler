# --x-spacing 110 is load-bearing: the layout was tuned at that spacing.
# The committed SVGs also carry manual geometry corrections that nf-metro has no
# directive for (the 'Short reads' caption re-anchored clear of the exit port,
# the database bundle and report lane routed below the reads trunk, the two file
# icons centred in their section boxes), so a plain re-render will not reproduce
# them byte-for-byte.
nf-metro render pipeline.mmd -o pipeline_light.svg --logo nf-core-funcprofiler_logo_light.png --theme light --animate --x-spacing 110
nf-metro render pipeline.mmd -o pipeline_nf-core.svg --logo nf-core-funcprofiler_logo_light.png --theme nfcore --animate --x-spacing 110
