###--------------------------------------------------------------------------###

# generate splines with 1 knot at the median for one variable

#@x: numeric vector
#@deg: degree of B-splines
#@coesSpl: coefficients for basis functions, if null a random vector generated

#return: splines values for this variable

simSpline <- function(x, deg=3, coefSpl=NULL){
  
  if (is.null(coefSpl)) coefSpl <- runif(deg + 2, 0, 1)
  bas <- splines::bs(x = x, knots = median(x), degree = deg, intercept = TRUE)
  return(as.vector(bas %*% coefSpl))
  
}

###--------------------------------------------------------------------------###

# generate a binary outcome with probit gam (splines for cont and nonlinear
# transformations of discrete variables) for a fixed R^2 in the latent variable
# mar or mnar data

#@dat: DT which must contain all relevant variables to be used as preds & Y if mnar
# it can be the same data over all repetitions or each time different

#return: a list of the binary indicator (R:num vector), coefs for GAM (coefs:num vector)

simProbit <- function(params, dat){
  
  z <- qnorm(1-params$pm)
  out <- data.table::data.table(LP=numeric(params$N))
  is.mnar <- params$mechanism == "mnar"
  allNms <- c(names(dat)[grep("^Rel", names(dat))],c("Y")[is.mnar])
  dat.rel <- data.table::copy(dat[,..allNms])
  
  # scale variables and assign moderately large coefs, the largest if mnar
  dat.rel[, (allNms) := lapply(.SD, scale), .SDcols = allNms]
  coefsRel <- runif(length(allNms), 0.3, 0.4)
  if (is.mnar) coefsRel[which(allNms == "Y")] <- max(coefsRel)*1.5
  
  # define residual variance for the linear predictor
  explSig <- t(coefsRel) %*% cov(dat.rel) %*% coefsRel
  #if (params$R2r %in% c(0,1)) stop('R**2 for indicator must not be 0 or 1.')
  resSig <- (explSig / params$R2r) - explSig
  
  # define theoretical sd of lp
  sd.LP <- as.numeric(sqrt(explSig + resSig))
  
  # calculate linear predictor
  out[, LP := as.matrix(dat.rel) %*% (coefsRel) + 
        stats::rnorm(params$N, 0, sqrt(resSig))]
  #discretise
  return(list(R=out[, as.numeric(LP > ((z) * (sd.LP)))], coefs=coefsRel))
  
}

###--------------------------------------------------------------------------###

# simulate missingness with a probit model or randomly

#@dat: see above

#return: a list of the binary indicator (R:num vector), coefs for GAM (coefs:num vector)

simR <- function(params, dat){
  
  if (params$mechanism == "mcar"){
    return(list(R=rbinom(params$N, size = 1, prob = params$pm),coefs=NULL))
  } else return(simProbit(params, dat))
  
}

###--------------------------------------------------------------------------###
