# how to run fro ./:
# snakemake -s ancestry.smk --jobs 5000 --latency-wait 30 --cluster-config config/cluster.json --cluster 'bsub -J {cluster.name} -q {cluster.queue} -n {cluster.n} -R {cluster.resources} -M {cluster.memory}  -o {cluster.output} -e  {cluster.error}' --keep-going --rerun-incomplete

configfile: "config/config_ancestry.yaml"

rule all:
    input:
        expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.kinship.rel",
            ukb=config["ukbdir"],
            maf=config["maf"]),
        expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.pca",
            ukb=config["ukbdir"],
            maf=config["maf"]),
        expand("{ukb}/ancestry/{hapmap}_ukb_imp_genome_v3_maf{maf}.pruned.merged.pca",
            ukb=config["ukbdir"],
            maf=config["maf"],
            hapmap=config["hapmap"]),
        expand("{ukb}/ancestry/HapMap_UKBB-FD_pca.png",
            ukb=config["ukbdir"]),
        expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.European.pca",
            ukb=config["ukbdir"],
            maf=config["maf"])

rule ukbSNPs:
    input:
        bed=expand("{ukb}/maf{maf}/ukb_imp_genome_v3_maf{maf}.pruned.bed",
            maf=config["maf-in"],
            ukb=config["ukbdir"]),
        bim=expand("{ukb}/maf{maf}/ukb_imp_genome_v4_maf{maf}.pruned.bim",
            maf=config["maf-in"],
            ukb=config["ukbdir"]),
        fam=expand("{ukb}/maf{maf}/ukb_imp_genome_v3_maf{maf}.pruned.fam",
            maf=config["maf-in"],
            ukb=config["ukbdir"])
    output:
        "{dir}/maf{maf}/ukb_imp_genome_v3_maf{maf}.pruned.bed",
        "{dir}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.snplist"
    shell:
        """
        plink2 --bed {input.bed} \
            --bim {input.bim} \
            --fam {input.fam} \
            --make-bed \
            --maf {wildcards.maf} \
            --write-snplist \
            --out {wildcards.dir}/maf{wildcards.maf}/ukb_imp_genome_v3_maf{wildcards.maf}.pruned
        cp {wildcards.dir}/maf{wildcards.maf}/ukb_imp_genome_v3_maf{wildcards.maf}.pruned.snplist \
           {wildcards.dir}/ancestry
        """

rule kinshipUKB:
    input:
        bed=expand("{ukb}/maf{maf}/ukb_imp_genome_v3_maf{maf}.pruned.bed",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        bim=expand("{ukb}/maf{maf}/ukb_imp_genome_v3_maf{maf}.pruned.bim",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        fam=expand("{ukb}/maf{maf}/ukb_imp_genome_v3_maf{maf}.pruned.fam",
            maf=config["maf"],
            ukb=config["ukbdir"])
    output:
        "{dir}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.kinship.rel"
    shell:
        "plink2 --bed {input.bed} \
                --fam {input.fam} \
                --bim {input.bim} \
                --make-rel square \
                --out {wildcards.dir}/ancestry/ukb_imp_genome_v3_maf{wildcards.maf}.pruned.kinship"

rule pcaUKB:
    input:
        bed=expand("{ukb}/maf{maf}/ukb_imp_genome_v3_maf{maf}.pruned.bed",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        bim=expand("{ukb}/maf{maf}/ukb_imp_genome_v3_maf{maf}.pruned.bim",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        fam=expand("{ukb}/maf{maf}/ukb_imp_genome_v3_maf{maf}.pruned.fam",
            maf=config["maf"],
            ukb=config["ukbdir"])
    output:
        "{dir}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.pca"
    shell:
        "flashpca --bed {input.bed} \
                --fam {input.fam} \
                --bim {input.bim} \
                --ndim 10 \
                --outpc {wildcards.dir}/ancestry/ukb_imp_genome_v3_maf{wildcards.maf}.pruned.pca \
                --outvec  {wildcards.dir}/ancestry/ukb_imp_genome_v3_maf{wildcards.maf}.pruned.eigenvectors \
                --outload  {wildcards.dir}/ancestry/ukb_imp_genome_v3_maf{wildcards.maf}.pruned.SNPloadings \
                --outval  {wildcards.dir}/ancestry/ukb_imp_genome_v3_maf{wildcards.maf}.pruned.eigenvalues \
                --outpve  {wildcards.dir}/ancestry/ukb_imp_genome_v3_maf{wildcards.maf}.pruned.variance_explained"


rule extractUKBfromHapmap:
    input:
        bed=expand("{hapdir}/{hapmap}.bed",
            hapdir=config["hapdir"],
            hapmap=config["hapmap"]),
        bim=expand("{hapdir}/{hapmap}.bim",
            hapdir=config["hapdir"],
            hapmap=config["hapmap"]),
        fam=expand("{hapdir}/{hapmap}.fam",
            hapdir=config["hapdir"],
            hapmap=config["hapmap"]),
        snplist=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.snplist",
            maf=config["maf"],
            ukb=config["ukbdir"])
    output:
        "{dir}/ancestry/HapMap{hapmap}.intersection.bed",
        "{dir}/ancestry/HapMap{hapmap}.intersection.snplist"
    shell:
        "plink2 --bed {input.bed} \
            --bim {input.bim} \
            --fam {input.fam} \
            --make-bed \
            --extract {input.snplist} \
            --write-snplist \
            --out {wildcards.dir}/ancestry/HapMap{wildcards.hapmap}.intersection"

rule extractHapmapFromUKB:
    input:
        bed=expand("{ukb}/maf{maf}/ukb_imp_genome_v3_maf{maf}.pruned.bed",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        bim=expand("{ukb}/maf{maf}/ukb_imp_genome_v3_maf{maf}.pruned.bim",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        fam=expand("{ukb}/maf{maf}/ukb_imp_genome_v3_maf{maf}.pruned.fam",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        snplist=expand("{ukb}/ancestry/{hapmap}.intersection.snplist",
            ukb=config["ukbdir"],
            hapmap=config["hapmap"])
    output:
        "{dir}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.bed"
    shell:
        "plink2 --bed {input.bed} \
            --bim {input.bim} \
            --fam {input.fam} \
            --make-bed \
            --extract {input.snplist} \
            --out {wildcards.dir}/ancestry/ukb_imp_genome_v3_maf{wildcards.maf}.pruned.intersection"

rule compareSNPs:
    input:
        ukb_bed=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.bed",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        ukb_bim=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.bim",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        ukb_fam=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.fam",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        hapmap_bed=expand("{ukb}/ancestry/{hapmap}.intersection.bed",
            ukb=config["ukbdir"],
            hapmap=config["hapmap"]),
        hapmap_bim=expand("{ukb}/ancestry/{hapmap}.intersection.bim",
            ukb=config["ukbdir"],
            hapmap=config["hapmap"]),
        hapmap_fam=expand("{ukb}/ancestry/{hapmap}.intersection.fam",
            ukb=config["ukbdir"],
            hapmap=config["hapmap"])
    output:
        "{dir}/ancestry/compare.{hapmap}.ukb_imp_v3_maf{maf}.pruned.missnp"
    shell:
        """
        set +e
        plink --bed {input.hapmap_bed} \
            --bim {input.hapmap_bim} \
            --fam {input.hapmap_fam} \
            --bmerge {input.ukb_bed} {input.ukb_bim} {input.ukb_fam} \
            --merge-mode 6 \
            --out {wildcards.dir}/ancestry/compare.{wildcards.hapmap}.ukb_imp_v3_maf{wildcards.maf}.pruned
        set -e
        """

rule excludeMissnpUKB:
    input:
        ukb_bed=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.bed",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        ukb_bim=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.bim",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        ukb_fam=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.fam",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        missnp=expand("{ukb}/ancestry/compare.{hapmap}.ukb_imp_v3_maf{maf}.pruned.missnp",
            ukb=config["ukbdir"],
            maf=config["maf"],
            hapmap=config["hapmap"])
    output:
        "{dir}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.nomissnp.bed"
    shell:
        "plink --bed {input.ukb_bed} \
            --bim {input.ukb_bim} \
            --fam {input.ukb_fam} \
            --exclude {input.missnp} \
            --make-bed \
            --out {wildcards.dir}/ancestry/ukb_imp_genome_v3_maf{wildcards.maf}.pruned.intersection.nomissnp"

rule excludeMissnpHapmap:
    input:
        hapmap_bed=expand("{ukb}/ancestry/{hapmap}.intersection.bed",
            ukb=config["ukbdir"],
            hapmap=config["hapmap"]),
        hapmap_bim=expand("{ukb}/ancestry/{hapmap}.intersection.bim",
            ukb=config["ukbdir"],
            hapmap=config["hapmap"]),
        hapmap_fam=expand("{ukb}/ancestry/{hapmap}.intersection.fam",
            ukb=config["ukbdir"],
            hapmap=config["hapmap"]),
        missnp=expand("{ukb}/ancestry/compare.{hapmap}.ukb_imp_v3_maf{maf}.pruned.missnp",
            ukb=config["ukbdir"],
            maf=config["maf"],
            hapmap=config["hapmap"])
    output:
        "{dir}/ancestry/HapMap{hapmap}.intersection.nomissnp.bed",
    shell:
        "plink --bed {input.hapmap_bed} \
            --bim {input.hapmap_bim} \
            --fam {input.hapmap_fam} \
            --exclude {input.missnp} \
            --make-bed \
            --out {wildcards.dir}/ancestry/HapMap{wildcards.hapmap}.intersection.nomissnp"

rule findMismatches:
    input:
        ukb_bim=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.nomissnp.bim",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        hapmap_bim=expand("{ukb}/ancestry/{hapmap}.intersection.nomissnp.bim",
            ukb=config["ukbdir"],
            hapmap=config["hapmap"])
    output:
        flippedAlleles="{dir}/ancestry/compare.{hapmap}.ukb_imp_v3_maf{maf}.pruned.flippedAlleles",
        same="{dir}/ancestry/compare.{hapmap}.ukb_imp_v3_maf{maf}.pruned.same",
        keep="{dir}/ancestry/compare.{hapmap}.ukb_imp_v3_maf{maf}.pruned.keep"
    shell:
        """
        awk 'FNR==NR {{a[$1$2$4$5$6]; next}} $1$2$4$5$6 in a' {input.ukb_bim} {input.hapmap_bim} > {output.same}
        awk 'FNR==NR {{a[$2$5$6]; next}} $2$6$5 in a {{print $2\t$6\t$5\t$5\t$6}}' {input.ukb_bim} {input.hapmap_bim} > {output.flippedAlleles}
        cut -f 2 {output.same} {output.flippedAlleles} > {output.keep}
        """

rule filterUKB:
    input:
        ukb_bed=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.nomissnp.bed",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        ukb_bim=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.nomissnp.bim",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        ukb_fam=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.nomissnp.fam",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        keep=expand("{ukb}/ancestry/compare.{hapmap}.ukb_imp_v3_maf{maf}.pruned.keep",
            ukb=config["ukbdir"],
            maf=config["maf"],
            hapmap=config["hapmap"])
    output:
        "{dir}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.matched.bed"
    shell:
        "plink --bed {input.ukb_bed} \
            --bim {input.ukb_bim} \
            --fam {input.ukb_fam} \
            --extract {input.keep} \
            --make-bed \
            --out {wildcards.dir}/ancestry/ukb_imp_genome_v3_maf{wildcards.maf}.pruned.intersection.matched"

rule filterAndFlipHapmap:
    input:
        hapmap_bed=expand("{ukb}/ancestry/{hapmap}.intersection.nomissnp.bed",
            ukb=config["ukbdir"],
            hapmap=config["hapmap"]),
        hapmap_bim=expand("{ukb}/ancestry/{hapmap}.intersection.nomissnp.bim",
            ukb=config["ukbdir"],
            hapmap=config["hapmap"]),
        hapmap_fam=expand("{ukb}/ancestry/{hapmap}.intersection.nomissnp.fam",
            ukb=config["ukbdir"],
            hapmap=config["hapmap"]),
        keep=expand("{ukb}/ancestry/compare.{hapmap}.ukb_imp_v3_maf{maf}.pruned.keep",
            ukb=config["ukbdir"],
            maf=config["maf"],
            hapmap=config["hapmap"]),
        flipped=expand("{ukb}/ancestry/compare.{hapmap}.ukb_imp_v3_maf{maf}.pruned.flippedAlleles",
            ukb=config["ukbdir"],
            maf=config["maf"],
            hapmap=config["hapmap"])
    output:
        "{dir}/ancestry/HapMap{hapmap}.intersection.matched.bed",
    shell:
        "plink --bed {input.hapmap_bed} \
            --bim {input.hapmap_bim} \
            --fam {input.hapmap_fam} \
            --extract {input.keep} \
            --update-alleles {input.flipped} \
            --make-bed \
            --out {wildcards.dir}/ancestry/HapMap{wildcards.hapmap}.intersection.matched"

rule mergeHapMap:
    input:
        ukb_bed=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.matched.bed",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        ukb_bim=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.matched.bim",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        ukb_fam=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.matched.fam",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        hapmap_bed=expand("{ukb}/ancestry/{hapmap}.intersection.matched.bed",
            ukb=config["ukbdir"],
            hapmap=config["hapmap"]),
        hapmap_bim=expand("{ukb}/ancestry/{hapmap}.intersection.matched.bim",
            ukb=config["ukbdir"],
            hapmap=config["hapmap"]),
        hapmap_fam=expand("{ukb}/ancestry/{hapmap}.intersection.matched.fam",
            ukb=config["ukbdir"],
            hapmap=config["hapmap"])
    output:
        "{dir}/ancestry/{hapmap}_ukb_imp_genome_v3_maf{maf}.pruned.merged.bed"
    shell:
        "plink --bed {input.hapmap_bed} \
            --bim {input.hapmap_bim} \
            --fam {input.hapmap_fam} \
            --bmerge {input.ukb_bed} {input.ukb_bim} {input.ukb_fam} \
            --out {wildcards.dir}/ancestry/{wildcards.hapmap}_ukb_imp_genome_v3_maf{wildcards.maf}.pruned.merged"

rule pcaMerge:
    input:
        bed=expand("{ukb}/ancestry/{hapmap}_ukb_imp_genome_v3_maf{maf}.pruned.merged.bed",
            maf=config["maf"],
            ukb=config["ukbdir"],
            hapmap=config["hapmap"]),
        bim=expand("{ukb}/ancestry/{hapmap}_ukb_imp_genome_v3_maf{maf}.pruned.merged.bim",
            maf=config["maf"],
            ukb=config["ukbdir"],
            hapmap=config["hapmap"]),
        fam=expand("{ukb}/ancestry/{hapmap}_ukb_imp_genome_v3_maf{maf}.pruned.merged.fam",
            maf=config["maf"],
            ukb=config["ukbdir"],
            hapmap=config["hapmap"])
    output:
        "{dir}/ancestry/{hapmap}_ukb_imp_genome_v3_maf{maf}.pruned.merged.pca"
    shell:
        "flashpca --bed {input.bed} \
                --fam {input.fam} \
                --bim {input.bim} \
                --ndim 10 \
                --outpc {wildcards.dir}/ancestry/{wildcards.hapmap}_ukb_imp_genome_v3_maf{wildcards.maf}.pruned.merged.pca \
                --outvec  {wildcards.dir}/ancestry/{wildcards.hapmap}_ukb_imp_genome_v3_maf{wildcards.maf}.pruned.merged.eigenvectors \
                --outload  {wildcards.dir}/ancestry/{wildcards.hapmap}_ukb_imp_genome_v3_maf{wildcards.maf}.pruned.merged.SNPloadings \
                --outval  {wildcards.dir}/ancestry/{wildcards.hapmap}_ukb_imp_genome_v3_maf{wildcards.maf}.pruned.merged.eigenvalues \
                --outpve  {wildcards.dir}/ancestry/{wildcards.hapmap}_ukb_imp_genome_v3_maf{wildcards.maf}.pruned.merged.variance_explained"

rule plotPCA:
    input:
        samples=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.intersection.matched.fam",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        pcafile=expand("{ukb}/ancestry/{hapmap}_ukb_imp_genome_v3_maf{maf}.pruned.merged_pca",
            maf=config["maf"],
            ukb=config["ukbdir"],
            hapmap=config['hapmap'])
    output:
        "{dir}/ancestry/HapMap_UKBB-FD_pca.png",
        "{dir}/ancestry/European_samples.csv"
    shell:
        "Rscript 'ancestry/selectPCA.R' --directory={wildcards.dir}/ancestry \
            --pcadata={input.pcafile} \
            --samples={input.samples} \
            --name=UKBB-FD"

rule filterEuropeans:
    input:
        keep="{dir}/ancestry/European_samples.csv",
        bed=expand("{ukb}/maf{maf}/ukb_imp_genome_v3_maf{maf}.pruned.bed",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        bim=expand("{ukb}/maf{maf}/ukb_imp_genome_v3_maf{maf}.pruned.bim",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        fam=expand("{ukb}/maf{maf}/ukb_imp_genome_v3_maf{maf}.pruned.fam",
            maf=config["maf"],
            ukb=config["ukbdir"])
    output:
        "{dir}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.European.fam",
        "{dir}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.European.bim",
        "{dir}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.European.bed"
    shell:
        "plink --bed {input.bed} \
            --fam {input.fam} \
            --bim {input.bim} \
            --keep {input.keep} \
            --make-bed \
            --out {wildcards.dir}/ancestry/ukb_imp_genome_v3_maf{wildcards.maf}.pruned.European"

rule pcaEuropean:
    input:
        bed=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.European.bed",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        bim=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.European.bim",
            maf=config["maf"],
            ukb=config["ukbdir"]),
        fam=expand("{ukb}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.European.fam",
            maf=config["maf"],
            ukb=config["ukbdir"])
    output:
        "{dir}/ancestry/ukb_imp_genome_v3_maf{maf}.pruned.European.pca"
    shell:
        "flashpca --bed {input.bed} \
                --fam {input.fam} \
                --bim {input.bim} \
                --ndim 10 \
                --outpc {wildcards.dir}/ancestry/ukb_imp_genome_v3_maf{wildcards.maf}.pruned.European.pca \
                --outvec  {wildcards.dir}/ancestry/ukb_imp_genome_v3_maf{wildcards.maf}.pruned.European.eigenvectors \
                --outload  {wildcards.dir}/ancestry/ukb_imp_genome_v3_maf{wildcards.maf}.pruned.European.SNPloadings \
                --outval  {wildcards.dir}/ancestry/ukb_imp_genome_v3_maf{wildcards.maf}.pruned.European.eigenvalues \
                --outpve  {wildcards.dir}/ancestry/ukb_imp_genome_v3_maf{wildcards.maf}.pruned.European.variance_explained"

