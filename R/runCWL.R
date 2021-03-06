#' run cwlParam
#' 
#' Execute a cwlParam object with assigned inputs.
#' @param cwl A `cwlParam` or `cwlStepParam` object.
#' @param prefix The prefix of `cwl` and `yml` file to write.
#' @param cwlRunner The path to the `cwltool` or `cwl-runner`. If not
#'     exists, the cwltool package will be installed by `reticulate`.
#' @param cwlTemp Whether to keep temporary files. If true, all
#'     temporary files will be kept in a "temp" folder of current
#'     output directory.
#' @param outdir Output directory, default current directory.
#' @param Args The arguments for `cwltool` or `cwl-runner`. For
#'     example, "--debug" can work with `cwltool` to show debug
#'     information.
#' @param stdout standard output from `system2`.
#' @param stderr standard error from `system2`. By setting it to "",
#'     the detailed running logs will return directly.
#' @param docker Whether to use docker.
#' @param ... The other options from `writeCWL` and `system2`.
#' @export
#' @return A list of outputs from tools and logs from cwltool.
#' @examples
#' input1 <- InputParam(id = "sth")
#' echo <- cwlParam(baseCommand = "echo",
#'                  inputs = InputParamList(input1))
#' echo$sth <- "Hello World!"
#' ## res <- runCWL(echo)
runCWL <- function(cwl, prefix = tempfile(), cwlRunner = "cwltool",
                   cwlTemp = FALSE, outdir = ".", Args = character(),
                   stdout = TRUE, stderr = TRUE, docker = TRUE, ...){
    if(length(unlist(.cwl2yml(cwl))) == 0) stop("Inputs are not defined")
    writeCWL(cwl, prefix = prefix, docker = docker, ...)

    ## check cwltool
    ext <- suppressWarnings(system(paste("which", cwlRunner),
                                   intern = TRUE))
    if(length(ext)==0){
        stop(cwlRunner, " is not found, ",
            "Please install cwltool first!\n",
             "https://github.com/common-workflow-language/cwltool#install")
    }
    
    if(cwlTemp){
        Args <- paste("--tmp-outdir-prefix temp/", Args)
    }
    res <- system2(cwlRunner,
                   args = paste0("--outdir ", outdir, " ", Args, " ",
                                 prefix, ".cwl ", prefix, ".yml"),
                   stdout = stdout, stderr = stderr, ...)
    ##return(res)
    message(tail(res, 1))

    if(stderr == TRUE) {
        if(cwlClass(cwl) == "CommandLineTool"){
            idx <- grep("^\\[job", res)
            command <- res[idx[1] : (idx[2]-1)]
        }else{
            command <- NULL
        }
        if(!any(grepl("path", res)) & any(grepl("location", res))){
            path <- read.table(textConnection(res[grep('\"location\":', res)]),
                               stringsAsFactors = FALSE)[,3]
        }else if(any(grepl("path", res))){
            path <- read.table(textConnection(res[grep('\"path\":', res)]),
                               stringsAsFactors = FALSE)[,3]
        }else{
            path <- NULL
        }
        SimpleList(command = command,
                   output = path,
                   logs = res)
    }else{
        res
    }
}


runFun <- function(idx, cwl, outdir, inputList, paramList = list(), ...){
    library(Rcwl)
    stopifnot(all(names(inputList) %in% names(inputs(cwl))))
    ## change output directory
    sname <- names(inputList[[1]])
    outdir <- file.path(outdir, sname[idx])
    dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
    ## assign inputs
    for(i in seq_along(inputList)){
        input1 <- inputList[[i]][[idx]]
        cwl <- .assignInput(cwl, names(inputList)[i], input1)
    }
    if(length(paramList) > 0){
        for(j in seq_along(paramList)){
            cwl <- .assignInput(cwl, names(paramList)[j], paramList[[j]])
        }
    }
    runCWL(cwl, outdir = outdir, ...)
}

#' run CWL with batchtools
#' 
#' @param cwl A `cwlParam` or `cwlStepParam` object.
#' @param outdir Directory to output results
#' @param inputList An input list to run in parallel. The list names
#'     must be in the inputs of cwl. Jobs will be submitted in
#'     parallel for each element in the list. The output directory of
#'     each job will be made using the name of each element under the
#'     `outdir`.
#' @param paramList A parameter list for the cwl. The list names must
#'     be in the inputs of cwl.
#' @param BPPARAM The options for `BiocParallelParam`.
#' @param ... The options from runCWL.
#' @import BiocParallel
#' @import batchtools
#' @export
#' @return Results from computing nodes and logs from cwltool.
runCWLBatch <- function(cwl, outdir = getwd(), inputList, paramList = list(),
                        BPPARAM = BatchtoolsParam(
                            workers = lengths(inputList)[1]), ...){
    nsample <- lengths(inputList)[1]
    if(!dir.exists(outdir)) dir.create(outdir, recursive = TRUE)
    bptry(bplapply(seq(nsample), runFun, BPPARAM = BPPARAM,
                   cwl = cwl, outdir = normalizePath(outdir),
                   inputList = inputList,
                   paramList = paramList, ...))
}
