library(data.table)
library(caret)
library(reshape2)
library(doMC)
registerDoMC(cores=12)

args <- c("R/svm_training.R",
          "svm_classification",
          "svm_test_results"
          )

## this is a version of predict.train from
## https://github.com/dondelelcaro/caret/tree/fix_obslevels_in_predict
my.predict.train <- function(object, newdata = NULL, type = "raw", na.action = na.omit, ...)
{
  if(all(names(object) != "modelInfo")) {
    object <- update(object, param = NULL)
  }
  if(!is.null(object$modelInfo$library))
    for(i in object$modelInfo$library) 
      do.call("require", list(package = i))
  if(!(type %in% c("raw", "prob"))) stop("type must be either \"raw\" or \"prob\"")
  if(type == "prob")
  {
    if (is.null(object$modelInfo$prob))
      stop("only classification models that produce probabilities are allowed")
  }
  
  if(!is.null(newdata))
  {
    if (inherits(object, "train.formula"))
    {
      newdata <- as.data.frame(newdata)
      rn <- row.names(newdata)
      Terms <- delete.response(object$terms)
      m <- model.frame(Terms, newdata, na.action = na.action, xlev = object$xlevels)
      if (!is.null(cl <- attr(Terms, "dataClasses"))) 
        .checkMFClasses(cl, m)
      keep <- match(row.names(m), rn)
      newdata <- model.matrix(Terms, m, contrasts = object$contrasts)
      xint <- match("(Intercept)", colnames(newdata), nomatch = 0)
      if (xint > 0) 
        newdata <- newdata[, -xint, drop = FALSE]   
    }
  }
  else {
    if(!is.null(object$trainingData))
    {            
      newdata <- if(object$method == "pam") object$finalModel$xData else object$trainingData
      ##newdata$.outcome <-NULL
    } else stop("please specify data via newdata")
  }
  
  if(type == "prob")
  {
    out <- extractProb(list(object),
                       unkX = newdata,
                       unkOnly = TRUE,
                       ...)
    obsLevels <- levels(object)
    out <- out[, make.names(obsLevels), drop = FALSE]
  } else {
    out <- extractPrediction(list(object),
                             unkX = newdata,
                             unkOnly = TRUE,
                             ...)$pred
  }
  
  out  
}


args <- commandArgs(trailingOnly=TRUE)

load(args[2])
source(args[1])

trained.object <- NULL
eval(parse(text=paste0("trained.object <- ",caret.run[["object_name"]])))

scale.and.zero <- function(x){
    x <- scale(x)
    x[!is.finite(x)] <- 0
    x
}

predictions.caret <- list()
### test the predictions using SVM
for (group in names(trained.object)) {
    predictions.caret[[group]] <-
        list()
    result <- 
        my.predict.train(trained.object[[group]],
                         newdata=scale.and.zero(genes.training[,c(gene.names)]),
                         type="prob")
    result$prediction <-
        colnames(result)[apply(result,1,which.max)]
    result$actual <-
        genes.training[,group]
    
    predictions.caret[[group]][["training"]] <- 
        result

    result <- 
        my.predict.train(trained.object[[group]],
                         newdata=scale.and.zero(genes.testing[,c(gene.names)]),
                         type="prob")
    result$prediction <-
        colnames(result)[apply(result,1,which.max)]
    result$actual <-
        genes.testing[,group]
    
    predictions.caret[[group]][["testing"]] <- 
        result
}

save.env <- new.env()
save.env[[caret.run[["predictions"]]]] <- predictions.caret

save(list=names(save.env),
     envir=save.env,
     file=args[length(args)])

