### R code from vignette source 'C:/Users/michae_sum/Documents/GIT/SGAT/vignettes/LightCurve.Rnw'

###################################################
### code chunk number 1: first
###################################################
set.seed(42)
library(SGAT)
data(ElephantSeal2)
data(ElephantSeal2calib)

calibration <- with(ElephantSeal2calib, approxfun(zenith, light, rule = 2))

library(raster)
library(maptools)
data(wrld_simpl)


lonlim <- c(110, 190)
latlim <- c(-70, -50)


land.mask <- function(poly, xlim, ylim, n = 4L, land = TRUE) {
  r <- raster(nrows = n * diff(ylim), ncols = n * diff(xlim),
              xmn = xlim[1L], xmx = xlim[2L],
              ymn= ylim[1L], ymx = ylim[2L],
              crs = projection(poly))
  r <- rasterize(poly, r)
  r <- as.matrix(is.na(r))[nrow(r):1L, ]
  if(land) r <- !r
  xbin <- seq(xlim[1L], xlim[2L], length=ncol(r) + 1L)
  ybin <- seq(ylim[1L], ylim[2L], length=nrow(r) + 1L)

  function(p) {
    r[cbind(.bincode(p[,2L], ybin),.bincode(p[,1L], xbin))]
  }
}

is.sea <- land.mask(wrld_simpl, xlim = lonlim, ylim = latlim, land = FALSE)


log.prior <- function(p)  {
  f <- is.sea(p)
  ifelse(f|is.na(f),0,-1000)
}


d <- ElephantSeal2 ##subset(ElephantSeal2, segment %in% 1:80)
d$segment <- unclass(factor(d$segment))

###################################################
### code chunk number 6: model
###################################################
model <- curve.model(d$time, d$light, d$segment, calibration,
                     logp.x = log.prior,
                     logp.z = log.prior,
                     alpha = c(7, 10), beta = c(8, 3.5))


###################################################
### code chunk number 7: init
###################################################
## find starting points, but search only further to the north
## to avoid get stuck on the continent
nx <- 30L
ny <- 25L
grid <- list(x = seq(lonlim[1L], lonlim[2L], length = nx),
             y = seq(latlim[1L] + 10, latlim[2L], length = ny),
             z = array(0, c(nx, ny, length(model$time))))
for (i in seq_along(grid$x)) {
        for (j in seq_along(grid$y)) {
            grid$z[i,j,] <- model$logpx(cbind(rep(grid$x[i], length(model$time)), grid$y[j], 0))
        }
    }

x0 <- cbind(as.matrix(expand.grid(grid$x, grid$y)[apply(grid$z, 3, which.max), ]), 0)

## the first and last locations are known
x0[1L, c(1L, 2L) ] <- c(158.950, -54.5)
x0[nrow(x0), c(1L, 2L)] <- x0[1L, c(1L, 2L)]

fixedx <- seq_len(nrow(x0)) %in% c(1, nrow(x0))



###################################################
### code chunk number 8: proposals
###################################################
x.proposal <- mvnorm(S=diag(c(0.005,0.005, 0.05)),n=nrow(x0))
z.proposal <- mvnorm(S=diag(c(0.005,0.005)),n=nrow(x0)-1)


###################################################
### code chunk number 9: run1
###################################################
fit <- estelle.metropolis(model,x.proposal,z.proposal,iters=20,thin=20, x0 = x0, z0 = (x0[-nrow(x0),1:2]+ x0[-1,1:2])/2)


##segments(x0[,1], x0[,2], chain.last(fit$x)[,1], chain.last(fit$x)[,2])
plot(chain.last(fit$x), type = "l")


lastx <- chain.last(fit$x)
while((!all(fixedx | log.prior(chain.last(fit$x)) == 0)) | !all(log.prior(chain.last(fit$z)) == 0)) {
fit <- estelle.metropolis(model,x.proposal,z.proposal,iters=40,thin=20, x0 = chain.last(fit$x), z0 = chain.last(fit$z))
##plot(rdist)
##points(lastx)
segments(lastx[,1], lastx[,2], chain.last(fit$x)[,1], chain.last(fit$x)[,2])
lastx <- chain.last(fit$x)


}


plot(chain.last(fit$x), type = "l")
x.proposal <- mvnorm(chain.cov(fit$x),s=0.3)
z.proposal <- mvnorm(chain.cov(fit$z),s=0.3)
fit <- estelle.metropolis(model,x.proposal,z.proposal,
                          x0=chain.last(fit$x),z0=chain.last(fit$z),
                          iters=300,thin=20)
plot(chain.last(fit$x), type = "l")
fit0 <- fit


opar <- par(mfrow=c(2,1),mar=c(3,5,2,1)+0.1)
k <- sample(nrow(x0),20)
matplot(t(cbind(fit$x[k,1,], fit$x[k,1,])),type="l",lty=1,col="dodgerblue",ylab="Lon")
matplot(t(cbind(fit$x[k,2,], fit$x[k,2,])),type="l",lty=1,col="firebrick",ylab="Lat")
par(opar)

## Tune proposals based on previous run
x.proposal <- mvnorm(chain.cov(fit$x,discard=100),s=0.3)
z.proposal <- mvnorm(chain.cov(fit$z,discard=100),s=0.3)
fit <- estelle.metropolis(model,x.proposal,z.proposal,
                          x0=chain.last(fit$x),z0=chain.last(fit$z),
                          iters=300,thin=20)
plot(chain.last(fit$x), type = "l")
## Tune proposals based on previous run
x.proposal <- mvnorm(chain.cov(fit$x),s=0.3)
z.proposal <- mvnorm(chain.cov(fit$z),s=0.3)
fit <- estelle.metropolis(model,x.proposal,z.proposal,
                          x0=chain.last(fit$x),z0=chain.last(fit$z),
                          iters=300,thin=20)


opar <- par(mfrow=c(2,1),mar=c(3,5,2,1)+0.1)
matplot(scale(t(fit$x[150,,]),scale=F),type="l",lty=1,col=c(2,4),
        xlab="",ylab=expression(x[150]))
matplot(scale(t(fit$z[150,,]),scale=F),type="l",lty=1,col=c(2,4),
        xlab="",ylab=expression(z[150]))
par(opar)

windows()
plot(chain.last(fit$x))
apply(fit$z, 3, points, pch = ".")
## Draw final sample
x.proposal <- mvnorm(chain.cov(fit$x),s=0.3)
z.proposal <- mvnorm(chain.cov(fit$z),s=0.3)
fit <- estelle.metropolis(model,x.proposal,z.proposal,
                          x0=chain.last(fit$x),z0=chain.last(fit$z),
                          iters=2000,thin=50)




