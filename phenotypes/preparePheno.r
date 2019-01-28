#################
## libraries ####
#################
options(import.path=c("/homes/hannah/analysis/fd",
                      "/homes/hannah/projects"))
options(bitmapType = 'cairo', device = 'pdf')

modules::import_package('ggplot2', attach=TRUE)
modules::import_package('GGally', attach=TRUE)
plinkqc <- modules::import_package('plinkQC')
optparse <- modules::import_package('optparse')
autofd <- modules::import('AutoFD_interpolation')


## functions ####

dob2age <- function(dob, refdate) {
             refyear = as.numeric(gsub(".*/", "", refdate))
             refmonth = gsub("\\d{1,2}/(\\d{1,2})/\\d{4}", "\\1", refdate)
             refmonth = as.numeric(gsub("^0","", refmonth))
             year = as.numeric(gsub(".*/", "", dob))
             month = gsub("\\d{1,2}/(\\d{1,2})/\\d{4}", "\\1", dob)
             month = as.numeric(gsub("^0","", month))
             age <- refyear - year
             age[(month-refmonth) < 0] <- age[(month-refmonth) < 0] - 1
             return(age)
             }

#################################
## parameters and input data ####
#################################
option_list <- list(
    make_option(c("-o", "--outdir"), action="store", dest="outdir",
               type="character", help="Path to output directory [default:
               %default].", default=NULL),
    make_option(c("-gd", "--genodir"), action="store", dest="genodir",
               type="character", help="Path to genotype directory [default:
               %default].", default=NULL),
    make_option(c("-p", "--pheno"), action="store", dest="pheno",
               type="character", help="Path to fd phenotype file [default:
               %default].", default=NULL),
    make_option(c("-c", "--cov"), action="store", dest="cov",
               type="character", help="Path to LV volume covariate file
               [default: %default].", default=NULL),
    make_option(c("-i", "--interpolate"), action="store", dest="interpolate",
               type="integer", help="Number of slices to interpolate to
               [default: %default].", default=9),
    make_option(c("-s", "--samples"), action="store", dest="samples",
               type="character", help="Path to ukb genotype samples file
               [default: %default].", default=NULL),
    make_option(c("-e", "--europeans"), action="store", dest="europeans",
               type="character", help="Path to European samples file generated
               by ancestry.smk [default: %default].", default=NULL),
    make_option(c("-pcs", "--pcs"), action="store", dest="pcs",
               type="character", help="Path to pca output file generated by
               flashpca [default: %default].", default=NULL),
    make_option(c("--path2plink"), action="store", dest="path2plink",
               type="character", help="Path to plink software
               [default: %default].", default=NULL),
    optparse$make_option(c("--debug"), action="store_true",
               dest="debug", default=FALSE, type="logical",
               help="If set, predefined arguments are used to test the script
               [default: %default].")
)

args <- optparse$parse_args(OptionParser(option_list=option_list))

if (args$debug) {
    args <- list()
    args$outdir <- "~/data/digital-heart/phenotype/FD"
    args$pheno <- "~/data/digital-heart/phenotype/FD/20181116_HVOLSegmentations_FD.csv"
    args$interpolate <- 9
    args$cov <- "~/data/digital-heart/phenotype/2Dphenotype/20160705_GenScan.txt"
    args$samples <- "~/data/digital-heart/genotype/imputation/combined/genotypes/gencall.combined.clean.related.chr1.sample"
    args$europeans <- "~/data/digital-heart/genotype/QC/combined/HVOL.gencall.combined.clean.related.fam"
    args$pcs <- "~/data/digital-heart/genotype/QC/combined/HVOL.gencall.combined.clean.related.eigenvec"
    args$path2plink <- "/homes/hannah/bin/plink"
    args$genodir <- "~/data/digital-heart/genotype/QC/combined"
}

################
## analysis ####
################

## Filter European HVOLs for related samples
# European HVOLs
european_hvol <- data.table::fread(args$europeans, data.table=FALSE,
                            stringsAsFactors=FALSE)

related <- plinkqc$check_relatedness(indir=args$genodir,
                                     name="HVOL.gencall.combined.clean.related",
                                     interactive=FALSE, verbose=TRUE,
                                     path2plink=args$path2plink)

relatedIDs <- as.character(related[[2]]$IID)
hvols <- european_hvol[!european_hvol[,1] %in% relatedIDs,]

## FD measurements ####
dataFD <- data.table::fread(args$pheno, data.table=FALSE,
                            stringsAsFactors=FALSE, na.strings=c("NA", "NaN"),
                            sep=",")
rownames(dataFD) <- dataFD[, 1]
colnames(dataFD)[colnames(dataFD) == 'FD - Slice 1'] <- 'Slice 1'
dataFD <- dataFD[,grepl("Slice \\d{1,2}", colnames(dataFD))]
colnames(dataFD) <- gsub(" ", "", colnames(dataFD))

## get european, hvol FDs
dataFD <- dataFD[rownames(dataFD) %in% hvols[,1],]

# Exclude individuals where less than 6 slices were measured
NaN_values <- c("Sparse myocardium", "Meagre blood pool","FD measure failed")
fd_notNA <- apply(dataFD, 1,  function(x) {
                length(which(!(is.na(x) | x %in% NaN_values))) > 5
                            })
dataFD <- dataFD[fd_notNA, ]

# interpolate FD slice measures
FDi <- autofd$interpolate$fracDecimate(data=dataFD,
                                       interpNoSlices=args$interpolate,
                                       id.col.name='rownames')
# summary fd measurements
summaryFDi <- data.frame(t(apply(as.matrix(FDi), 1,
                                          autofd$stats$summaryStatistics,
                       discard=FALSE, sections="BMA")))

# plot distribution of FD along heart
FDalongHeart <- reshape2::melt(FDi, value.name = "FD")
colnames(FDalongHeart)[1:2] <- c("ID", "Slice")

FDalongHeart$Slice <- as.factor(as.numeric(gsub("Slice_", "",
                                                FDalongHeart$Slice)))
FDalongHeart$Location <- "Apical section"
FDalongHeart$Location[as.numeric(FDalongHeart$Slice) <= 3] <- "Basal section"
FDalongHeart$Location[as.numeric(FDalongHeart$Slice) <= 6 &
                      as.numeric(FDalongHeart$Slice) > 3] <- "Mid section"
FDalongHeart$Location <- factor(FDalongHeart$Location,
                                levels=c("Basal section", "Mid section",
                                         "Apical section"))

p_fd <- ggplot(data=FDalongHeart)
p_fd <- p_fd + geom_boxplot(aes(x=Slice, y=FD, color=Location)) +
    scale_color_manual(values=c('#fdcc8a','#fc8d59','#e34a33')) +
    labs(x="Slice", y="FD") +
    theme_bw()
ggsave(plot=p_fd, file=paste(args$outdir, "/FDAlongHeart_slices",
                             args$interpolate, ".pdf", sep=""),
       height=4, width=4, units="in")



## 2D phenotypes ####
covs <- read.table(args$cov, stringsAsFactors=FALSE,  fill=TRUE, sep="\t",
                   quote = "", header=TRUE)
covs <- covs[!duplicated(covs$Bru.Number),]

# all digital-heart imputed genotypes in bgen format
samples <- data.table::fread(args$samples, data.table=FALSE, skip=2,
                             stringsAsFactors=FALSE)[,1:2]
colnames(samples) <- c("FID", "IID")


# Principal components of European ancestry
pcs <- data.table::fread(args$pcs, data.table=FALSE, stringsAsFactors=FALSE)
colnames(pcs) <- c("FID", "IID", paste("PC", 1:(ncol(pcs)-2), sep=""))

## get covariates data ####
# grep columns with covariates sex, age, bmi and weight
sex <- which(grepl("sex", tolower(colnames(covs))))
mridate <- which(grepl("mri.scan", tolower(colnames(covs))))
dob <- which(grepl("dob", tolower(colnames(covs))))
weight <- which(grepl("weight", tolower(colnames(covs))))
height <- which(grepl("height", tolower(colnames(covs))))


relevant <- c(sex, dob, mridate, weight[2], height)

covariates <- covs[, relevant]
covNas <- c(apply(covariates, 1, function(x) any(is.na(x))) |
            apply(covariates, 1, function(x) any(x =="")))

covs <- covs[!covNas,]
covariates <- covariates[!covNas,]

colnames(covariates) <- c("sex", "dob", "mridate", "weight", "height")
covariates$sex <- as.numeric(as.factor(covariates$sex))
covariates$bmi <- covariates$weight/(covariates$height/100)^2
covariates$age <- dob2age(covariates$dob, covariates$mridate)
covariates$bsa <- sqrt(covariates$weight * covariates$height/3600)
rownames(covariates) <- covs$Bru.Number
covariates <- dplyr::select(covariates, sex, age, weight, height, bmi)

write.table(data.frame(bru=covs$Bru.Number, covariates),
            paste(args$outdir, "/Covariates_all_BRU", ".csv", sep=""),
            sep=",", row.names=FALSE, col.names=TRUE, quote=FALSE)

## Merge FD measures and covariates to order by samples ####
fd_all <- merge(summaryFDi[,-c(1,2,4,6,8)], FDi, by=0)
fd_all <- merge(fd_all, covariates, by.x=1, by.y=0)
fd_all$sex <- as.factor(fd_all$sex)

fd_pheno <- dplyr::select(fd_all, MeanBasalFD, MeanMidFD, MeanApicalFD)

fd_cov <- dplyr::select(fd_all, sex, age, weight, bmi, height)

slices <- paste("Slice_", 1:args$interpolate, sep="")
fd_slices <- dplyr::select(fd_all, slices)

write.table(fd_all, paste(args$outdir, "/FD_all_slices", args$interpolate,
                          ".csv", sep=""),
            sep=",", row.names=fd_all$Row.names, col.names=NA, quote=FALSE)
write.table(fd_pheno, paste(args$outdir, "/FD_phenotypes_slices",
                            args$interpolate, ".csv", sep=""),
            sep=",", row.names=fd_all$Row.names, col.names=NA, quote=FALSE)
write.table(fd_cov, paste(args$outdir, "/FD_covariates.csv", sep=""),
            sep=",", row.names=fd_all$Row.names, col.names=NA, quote=FALSE)


## Plot distribution of covariates ####
df <- dplyr::select(fd_all, MeanBasalFD, MeanMidFD, MeanApicalFD,
                    sex, age, height, weight, bmi)
p <- ggpairs(df,
             upper = list(continuous = wrap("density", col="#b30000",
                                            size=0.1)),
             diag = list(continuous = wrap("densityDiag", size=0.4)),
             lower = list(continuous = wrap("smooth", alpha=0.5,size=0.1,
                                            pch=20),
                          combo = wrap("facethist")),
             columnLabels = c("meanBasalFD", "meanMidFD",
                              "meanApicalFD",
                              "Sex~(f/m)", "Age~(years)", "Height~(m)",
                              "Weight~(kg)", "BMI~(kg/m^2)"),
             labeller = 'label_parsed',
             axisLabels = "show") +
    theme_bw() +
    theme(panel.grid = element_blank(),
          axis.text = element_text(size=6),
          axis.text.x = element_text(angle=90),
          strip.text = element_text(size=8),
          strip.background = element_rect(fill="white", colour=NA))
ggsave(plot=p, file=paste(args$outdir, "/pairs_fdcovariates.png", sep=""),
       height=12, width=12, units="in")


## Test association with all covs and principal components ####
fd_all <- merge(fd_all, pcs[,-1], by=1)
index_pheno <- which(grepl("FD", colnames(fd_all)))
index_slices <- which(grepl("Slice_", colnames(fd_all)))
index_antro <- 14:18
index_cov <- c(19:ncol(fd_all))

lm_fd_pcs <- sapply(index_pheno, function(x) {
    tmp <- lm(y ~ ., data=data.frame(y=fd_all[,x], fd_all[,index_cov]))
    summary(tmp)$coefficient[,4]
})
colnames(lm_fd_pcs) <- colnames(fd_all)[index_pheno]
rownames(lm_fd_pcs) <- c("intercept", colnames(fd_all)[index_cov])
sigAssociations <- which(apply(lm_fd_pcs, 1, function(x) any(x < 0.05)))

fd_all <- fd_all[,c(1,index_pheno, index_slices, index_antro,
    which(colnames(fd_all) %in% names(sigAssociations)))]

write.table(lm_fd_pcs[sigAssociations,],
            paste(args$outdir, "/FD_cov_associations.csv", sep=""), sep=",",
            row.names=TRUE, col.names=NA, quote=FALSE)
write.table(fd_all[,index_pheno],
            paste(args$outdir, "/FD_phenotypes.csv", sep=""),
            sep=",",
            row.names=fd_all$Row.names, col.names=NA, quote=FALSE)
write.table(fd_all[,-c(1, index_pheno, index_slices)],
            paste(args$outdir, "/FD_covariates.csv", sep=""), sep=",",
            row.names=fd_all$Row.names, col.names=NA, quote=FALSE)
write.table(fd_all[, index_slices],
            paste(args$outdir, "/FD_slices.csv", sep=""), sep=",",
            row.names=fd_all$Row.names, col.names=NA, quote=FALSE)

## Format phenotypes and covariates for bgenie ####
# Everything has to be matched to order in sample file; excluded and missing
# samples will have to be included in phenotypes and covariates and values set
# to -999

fd_bgenie <- merge(samples, fd_all, by=1, all.x=TRUE, sort=FALSE)
fd_bgenie <- fd_bgenie[match(samples$IID, fd_bgenie$IID),]
fd_bgenie$sex <- as.numeric(fd_bgenie$sex)
fd_bgenie[is.na(fd_bgenie)] <- -999

write.table(fd_bgenie[, (index_pheno + 1)],
            paste(args$outdir, "/FD_phenotypes_bgenie.txt", sep=""), sep=" ",
            row.names=FALSE, col.names=TRUE, quote=FALSE)
write.table(fd_bgenie[, (index_slices + 1)],
            paste(args$outdir, "/FD_slices_bgenie.txt", sep=""), sep=" ",
            row.names=FALSE, col.names=TRUE, quote=FALSE)
write.table(fd_bgenie[,-c(1:4, index_pheno + 1, index_slices + 1)],
            paste(args$outdir, "/FD_covariates_bgenie.txt", sep=""), sep=" ",
            row.names=FALSE, col.names=TRUE, quote=FALSE)

