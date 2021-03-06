\name{svygnm}
\alias{svygnm}
\alias{svygnm.svyrep.design}
\title{Fitting Generalized Nonlinear Models With Complex Survey Data}
\description{
     Fit association models to data from a complex survey
     design, with inverse-probability weighting and (optionally)
     standard errors based on replicate weights.
}
\usage{
svygnm(formula, design, ...) 
\S3method{svygnm}{svyrep.design}(formula, design,
    subset = NULL, data.fun = NULL, rho = NULL, 
    return.replicates = FALSE, keep.weights = FALSE, na.action, 
    eliminate, ncpus = getOption("boot.ncpus"), ...)
}
\arguments{
  \item{formula}{a symbolic description of the nonlinear predictor.}
  \item{design}{a survey object; if \code{se == "replicate"}, must be of class
                \code{\link[survey]{svrepdesign}} (see \dQuote{Details} below).
                Must contain all variables in the formula}
  \item{subset}{expression to select a subpopulation}
  \item{data.fun}{function called on each replicate to generate the \code{data} argument
                  passed to \code{\link[gnm]{gnm}}. If not \code{NULL},
                  it will be passed \code{design} and \code{...} as arguments, and must
                  return a \code{data.frame} object. This is primarily useful to compute a
                  frequency table and fit log-linear models.}
  \item{rho}{For replicate BRR designs, to specify the parameter for
             Fay's variance method, giving weights of \code{rho} and \code{2-rho}}
  \item{return.replicates}{return the replicates as a component of the result?}
  \item{keep.weights}{whether to save the weights in the \code{survey.design$pweights}
                      component of the result; note this typically uses a lot of memory.}
  \item{na.action}{handling of NAs}
  \item{eliminate}{a factor to be included as the first term in the model.
                   \code{\link[gnm]{gnm}} will exploit the structure of this factor to improve
                   computational efficiency. See details.}
  \item{ncpus}{the number of CPU cores to use to run replicates. Pass \code{NULL} to use the actual
               number of cores with an upper limit of 5.}
  \item{\dots}{more arguments to be passed to \code{\link[gnm]{gnm}}}
}
\details{
     This function can be used in a similar way as \code{\link[survey]{svyglm}},
     but for generalized nonlinear models. It computes standard errors
     using replicates only (i.e. no asymptotic standard errors). If your
     data does not come with replicate weights, use
     \code{\link[survey]{as.svrepdesign}} to create them first, and pass
     the resulting \code{\link[survey]{svrepdesign}} object via the
     \code{design} argument.
}
\value{
  An \code{svygnm} object.
}
\note{
  Note that printed fit statistics and degrees of freedom rely on the
  iid assumption. This is also the case of the variance-covariance matrix
  returned by the \code{\link[gnm]{vcov.gnm}} function.
}
\references{
  Rao, J.N.K., Scott, A.J. (1984). On Chi-squared Tests For Multiway
  Contingency Tables with Proportions Estimated From Survey Data.
  \emph{Annals of Statistics} 12, 46-60.
}
\author{
  Milan Bouchet-Valat, based on the \code{\link[survey]{svyglm}} function by Thomas Lumley
}
\examples{
  library(survey)
  data(api)
  dstrat<-svydesign(id=~1,strata=~stype, weights=~pw, data=apistrat, fpc=~fpc)
  rstrat<-as.svrepdesign(dstrat)
  glm.mod <- svyglm(api00~ell+meals+mobility, design=rstrat)
  gnm.mod <- svygnm(api00~ell+meals+mobility, design=rstrat, ncpus=1)
  # Both functions give the same result for GLMs
  summary(glm.mod)
  summary(gnm.mod)
  \dontshow{
  stopifnot(all.equal(c(coef(glm.mod)), c(coef(gnm.mod))))
  stopifnot(all.equal(c(vcov(glm.mod)), c(vcov(gnm.mod))))
  stopifnot(all.equal(model.matrix(glm.mod), model.matrix(gnm.mod)))
  stopifnot(all.equal(residuals(glm.mod), residuals(gnm.mod)))
  stopifnot(all.equal(summary(glm.mod)$coefficients, summary(gnm.mod)$coefficients))
  }

  # GNM, can only be fitted with svygnm()
  summary(svygnm(api00~ell+meals+mobility, design=rstrat, family=poisson, ncpus=1))
}
\seealso{
  \code{\link[gnm]{gnm}}, \code{\link[survey]{svyglm}}, \code{\link[survey]{as.svrepdesign}}
}
\keyword{ models }
\keyword{ nonlinear }
