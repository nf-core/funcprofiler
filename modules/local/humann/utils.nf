def getProcessName(task_process) {
    return task_process.tokenize(':')[-1]
}

def getContainer(name)  {
    return [
	'HUMANN3': 'ghcr.io/vdblab/biobakery-profiler:4.0.5--3.6.1',
	'HUMANN4': 'ghcr.io/vdblab/biobakery-profiler:4.0.6--4.0.0.alpha.1-final'
    ][name]
}
def getConda(name) {
    return [
	'HUMANN3': 'bioconda::humann=3.6.1',
	'HUMANN4': 'bioconda::humann=4.0.0.alpha.1-final'
    ][name]
}
def getExt(name) {
    return [
	'HUMANN3': '*.ffn.gz',
	'HUMANN4': '*.fna.gz'
    ][name]
}
