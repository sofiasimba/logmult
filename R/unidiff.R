## UNIDIFF model (Erikson & Goldthorpe, 1992), or uniform layer effect model (Xie, 1992)

unidiff <- function(tab, diagonal=c("included", "excluded", "only"),
                    constrain="auto", family=poisson,
                    tolerance=1e-6, iterMax=5000,
                    trace=FALSE, verbose=TRUE, ...) {
  diagonal <- match.arg(diagonal)

  tab <- as.table(tab)

  if(length(dim(tab)) < 3)
      stop("tab must have (at least) three dimensions")

  if(diagonal != "included" &&
     (nrow(tab) != ncol(tab) || !all(rownames(tab) == colnames(tab))))
     stop(sprintf("diagonal = %s is only supported for square tables with identical row and column categories",
                  diagonal))

  if(length(dim(tab)) > 3)
      tab <- margin.table(tab, 1:3)

  # When gnm evaluates the formulas, tab will have been converted to a data.frame,
  # with a fallback if both names are empty
  vars <- make.names(names(dimnames(tab)))
  if(length(vars) == 0)
      vars <- c("Var1", "Var2", "Var3")

  f <- sprintf("Freq ~ %s + %s + %s + %s:%s + %s:%s",
               vars[1], vars[2], vars[3], vars[1], vars[3], vars[2], vars[3])

  if(diagonal == "included") {
      f <- sprintf("%s + Mult(Exp(%s), %s:%s)", f, vars[3], vars[1], vars[2])

      if(identical(constrain, "auto"))
          constrain <- sprintf("(Mult\\(Exp\\(.\\), \\Q%s:%s\\E\\)\\Q.%s%s\\E)|(Mult\\(Exp\\(\\Q%s\\E.*\\.(\\Q%s%s\\E:)|(:\\Q%s%s\\E$))",
                               vars[1], vars[2], vars[3], dimnames(tab)[[3]][1],
                               vars[3], vars[1], rownames(tab)[1], vars[2], colnames(tab)[1])
  }
  if(diagonal == "excluded") {
      f <- sprintf("%s + %s:Diag(%s, %s) + Mult(Exp(%s), %s:%s)",
                   f, vars[3], vars[1], vars[2], vars[3], vars[1], vars[2])

      if(identical(constrain, "auto"))
          # Last pattern matches diagonal coefficients
          constrain <- sprintf("(Mult\\(Exp\\(.\\), \\Q%s:%s\\E\\)\\Q.%s%s\\E)|(Mult\\(Exp\\(\\Q%s\\E.*\\.(\\Q%s\\E)$)",
                               vars[1], vars[2], vars[3], dimnames(tab)[[3]][1],
                               vars[3], paste(paste(vars[1], rownames(tab), ":", vars[2],
                                                    rownames(tab), sep=""), collapse="\\E|\\Q"))
  }
  else if(diagonal == "only") {
      f <- sprintf("%s + Mult(Exp(%s), Diag(%s, %s))", f, vars[3], vars[1], vars[2])

      if(identical(constrain, "auto"))
          constrain <- sprintf("(Mult\\(Exp\\(.\\), Diag\\(\\Q%s, %s\\E\\)\\)\\Q.%s%s\\E)|(Mult\\(Exp\\(\\Q%s\\E.*\\.(\\Q%s%s\\E:)|(:\\Q%s%s\\E$))",
                               vars[1], vars[2], vars[3], dimnames(tab)[[3]][1],
                               vars[3], vars[1], rownames(tab)[1], vars[2], colnames(tab)[1])
  }


  # FIXME: we should be able to eliminate 3:1, but this triggers a "numerically singular system" error
#  if(missing(eliminate))
#      eliminate <- eval(parse(text=sprintf("quote(%s:%s)", vars[1], vars[3])))

  # We need to handle ... manually, else they would not be found when modelFormula() evaluates the call
  args <- list(formula=as.formula(f), data=tab, constrain=constrain,
               family=family, tolerance=tolerance, iterMax=iterMax,
               trace=trace, verbose=verbose)

  model <- do.call("gnm", c(args, list(...)))

  if(is.null(model))
      return(NULL)

  model$unidiff <- list()
  
  model$unidiff$layer <- getContrasts(model, pickCoef(model, sprintf("Mult\\(Exp\\(\\.\\)", vars[3])),
                                      "first", check=FALSE)


  if(diagonal == "included") {
      mat <- tab[,,1]
      nr <- nrow(mat)
      nc <- ncol(mat)
      con <- matrix(0, length(coef(model)), length(mat))
      ind <- pickCoef(model, sprintf("Mult\\(Exp\\(\\Q%s\\E\\)", vars[3]))
      for(i in 1:nr) {
          for(j in 1:nc) {
              mat[] <- 0
              mat[i,] <- -1/nc
              mat[,j] <- -1/nr
              mat[i,j] <- 1 - 1/nc - 1/nr
              mat <- mat + 1/(nr * nc)
              con[ind, (j - 1) * nr + i] <- mat
          }
      }

      colnames(con) <- names(ind)
      model$unidiff$interaction <- gnm:::se(model, con)
  }
  else if(diagonal == "only"){
      # Quasi-variances cannot be computed for these coefficients, so hide the warning
      # Also skip the reference level
      suppressMessages(model$unidiff$interaction <- getContrasts(model, pickCoef(model, sprintf("Mult\\(Exp\\(\\Q%s\\E\\)", vars[3])),
                                                                 ref="first", check=TRUE)$qvframe[-1,])

     # Diag() sorts levels alphabetically, which is not practical
     model$unidiff$interaction[c(1 + order(rownames(tab))),] <- model$unidiff$interaction
  }
  else {
     # Interaction coefficients cannot be identified for now
     model$unidiff$interaction <- NULL
  }

  rownames(model$unidiff$layer$qvframe) <- dimnames(tab)[[3]]

  if(diagonal != "excluded")
      rownames(model$unidiff$interaction) <- gsub(sprintf("Mult\\(Exp\\(\\Q%s\\E\\), \\.\\)\\.(Diag\\(%s, %s\\))?",
                                                          vars[3], vars[1], vars[2]), "",
                                                  rownames(model$unidiff$interaction))

  model$unidiff$diagonal <- diagonal

  class(model) <- c("unidiff", class(model))

  model$call <- match.call()

  model
}

print.unidiff <- function(x, digits=max(3, getOption("digits") - 4), ...) {
  cat("Call:\n", deparse(x$call), "\n", sep="", fill=TRUE)

  if(x$unidiff$diagonal == "included") {
      cat("\nFull two-way interaction coefficients:\n")
      interaction <- x$data[,,1]
      interaction[] <- x$unidiff$interaction[,1]
  }
  else if(x$unidiff$diagonal == "only") {
      cat("\nDiagonal interaction coefficients:\n")
      interaction <- x$unidiff$interaction[,1]
      names(interaction) <- rownames(x$unidiff$interaction)
  }
  else {
      cat("\nDiagonal interaction coefficients:\n")
      interaction <- "Not supported."
  }

  print.default(format(interaction, digits=digits, ...), quote=FALSE, print.gap=2)

  printModelStats(x)

  invisible(x)
}

summary.unidiff <- function(object, ...) {
  layer <- object$unidiff$layer$qvframe[,-4]
  interaction <- object$unidiff$interaction

  layer <- cbind(exp(layer[,1]), layer, 2 * pnorm(-abs(layer[,1]/layer[,2])))
  colnames(layer) <- c("Exp(Estimate)", "Estimate", "Std. Error", "Quasi SE", "Pr(>|z|)")
  rownames(layer) <- paste(names(dimnames(object$data))[3], rownames(layer), sep="")

  if(object$unidiff$diagonal != "excluded") {
      interaction <- cbind(interaction, 2 * pnorm(-abs(interaction[,1]/interaction[,2])))
      colnames(interaction) <- c("Estimate", "Std. Error", "Pr(>|z|)")
  }

  res <- list(call=object$call, diagonal=object$unidiff$diagonal,
              deviance.resid=residuals(object, type="deviance"),
              chisq=sum(residuals(object, "pearson")^2),
              dissim=sum(abs(abs(residuals(object, "response"))))/sum(abs(fitted(object)))/2,
              layer=layer, interaction=interaction,
              deviance=object$deviance, df.residual=object$df.residual,
              bic=extractAIC(object, k=log(sum(object$data)))[2],
              aic=extractAIC(object)[2])

  class(res) <- "summary.unidiff"

  res
}

print.summary.unidiff <- function(x, digits=max(3, getOption("digits") - 4), ...) {
  printModelHeading(x, digits)

  cat("\nLayer coefficients:\n")
  printCoefmat(x$layer, digits, signif.legend=FALSE, print.gap=2, ...)

  if(x$diagonal != "only")
      cat("\nFull two-way interaction coefficients:\n")
  else
      cat("\nDiagonal interaction coefficients:\n")

  if(x$diagonal != "excluded")
      printCoefmat(x$interaction, digits, has.Pvalue=TRUE, print.gap=2, ...)
  else
      cat("Not supported.\n")


  cat("\nDeviance:            ", format(x$deviance, digits),
      "\nPearson chi-squared: ", format(x$chisq, digits),
      "\nDissimilarity index: ", format(x$dissim * 100, digits), "%",
      "\nResidual df:         ", x$df.residual,
      "\nBIC:                 ", x$aic,
      "\nAIC:                 ", x$bic, "\n", sep="")
}

plot.unidiff <- function(x, exponentiate=TRUE, se.type=c("quasi.se", "se"), conf.int=.95,
                         numeric.auto=TRUE, type="o",
                         xlab=names(dimnames(x$data))[3], ylab="Layer coefficient", ...) {
  if(!inherits(x, "unidiff"))
      stop("x must be a unidiff object")

  se.type <- match.arg(se.type)

  qv <- x$unidiff$layer$qvframe

  w <- qnorm((1 - conf.int)/2, lower.tail=FALSE)

  coefs <- qv$estimate

  if(se.type == "quasi.se") {
      tops <- qv$estimate + w * qv$quasiSE
      tails <- qv$estimate - w * qv$quasiSE
   }
   else {
      tops <- qv$estimate + w * qv$SE
      tails <- qv$estimate - w * qv$SE
   }

  if(exponentiate) {
      coefs <- exp(coefs)
      tops <- exp(tops)
      tails <- exp(tails)
  }

  range <- max(tops) - min(tails)
  ylim <- c(min(tails) - range/20, max(tops) + range/20)

  # plot() converts x coordinates to numeric if possible, but segments
  # needs a real coordinate, so convert directly
  if(numeric.auto && !any(is.na(as.numeric(rownames(qv)))))
      at <- as.numeric(rownames(qv))
  else
      at <- factor(rownames(qv), levels=rownames(qv))

  plot.default(at, coefs, type=type, xaxt="n",
       ylim=ylim, xlab=xlab, ylab=ylab, ...)
  axis(1, at, labels=at)
  segments(as.numeric(at), tails, as.numeric(at), tops)

  invisible(x)
}