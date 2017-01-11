library(RSQLite)
library(rstan)
library(insol)
library(plyr)
library(zoo)

setwd("~/repos/brew-watch/model")
conn <- dbConnect(RSQLite::SQLite(), "data.s3db")
result <- dbSendQuery(conn, "select * from measurement where lux is not NULL")
measurements <- dbFetch(result, n=-1)
print(dim(measurements))
dbClearResult(result)
dbDisconnect(conn)
measurements$date <- strptime(measurements$timestamp, format="%Y-%m-%dT%H:%M:%OS")
measurements$tempc <- (measurements$temperature_f - 32) / 1.8

weather <- read.csv("weather.csv")
weather$tempc <- (weather$temperature - 32) / 1.8
temp.fun <- approxfun(weather$time, weather$tempc)

measurements.with.lux <- subset(measurements, !is.na(lux) & measurements$date < as.POSIXlt("2017-01-09"))

# azimuth: related to east/west progression through the sky
# zenith: related to elevation
measurements.with.lux$fractional.julian.day <- JD(measurements.with.lux$date)
measurements.with.lux$azimuth <- sunpos(sunvector(
  measurements.with.lux$fractional.julian.day, 42.395199,-72.5315332,1))[, 1]

measurements.with.lux$ticks <- as.numeric(measurements.with.lux$date)
measurements.with.lux$ext.temp <- temp.fun(measurements.with.lux$ticks)
measurements.with.lux$dow <- as.numeric(factor(weekdays(measurements.with.lux$date), 
                                               levels=c("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")))
measurements.with.lux$hour <- as.numeric(format(measurements.with.lux$date, "%H"))
measurements.with.lux$prev.ext.temp <- c(NA, measurements.with.lux[1:(nrow(measurements.with.lux) - 1), ]$ext.temp)
measurements.with.lux$tempc.lag1 <- c(NA, measurements.with.lux[1:(nrow(measurements.with.lux) - 1), ]$tempc)
measurements.with.lux$tempc.lag2 <- c(NA, NA, measurements.with.lux[1:(nrow(measurements.with.lux) - 2), ]$tempc)


diffs <- diff(measurements.with.lux$tempc, lag=1)
measurements.with.lux$is.changepoint <- c(NA, aaply(2:(nrow(measurements.with.lux)-1), 1, function(i) {
  sign(diffs[i-1]) != sign(diffs[i])
}), NA)

measurements.with.lux$time.since.changepoint <- c(NA, aaply(2:(nrow(measurements.with.lux)-1), 1, function(i) {
  measurements.with.lux$ticks[i] - max(measurements.with.lux$ticks[which(measurements.with.lux$is.changepoint[1:i])])
}), NA)

ggplot(measurements.with.lux, aes(x=ticks, y=tempc)) + geom_line(aes(color=log(time.since.changepoint))) + 
  geom_point(aes(alpha=is.changepoint))

measurements.with.lux$diff <- with(measurements.with.lux, tempc.lag1 - tempc.lag2)

model.dat <- subset(measurements.with.lux, ticks > 1483750000 & ticks < 1483850000)
model <- lm(tempc ~ tempc.lag1 + tempc.lag2, model.dat, na.action=na.exclude)
model.dat$fitted <- fitted(model)
step.size <- median(diff(model.dat$ticks))
simulate <- function(record, nsteps=10) {
  results <- NULL
  record <- record[, c("ticks", "tempc", "tempc.lag1", "tempc.lag2")]
  for(i in 1:nsteps) {
    old.record <- record
    new.temp <- predict(model, newdata=record)
    record$tempc <- new.temp
    record$tempc.lag1 <- old.record$tempc
    record$tempc.lag2 <- old.record$tempc.lag1
    record$ticks <- old.record$ticks + step.size
    results <- rbind(results, record)
  }
  return(results)
}
print(summary(model))

arima(model.dat$tempc, order=c(2, 0, 0))

ggplot(model.dat, aes(x=ticks, y=tempc)) + geom_line() + geom_point()  + 
  geom_line(aes(y=fitted), color="red") + 
  geom_line(data=simulate(simulate(model.dat[nrow(model.dat), ])), aes(x=ticks, y=tempc), color="blue")

model.data <- with(subset(measurements.with.lux, !is.na(tempc.lag2)), list(
  N = length(date),
  delta_t_mins = 10,
  day_of_week = dow,
  hour_of_day = hour,
  sun_azimuth = azimuth,
  lux = lux,
  prev_external_temp = prev.ext.temp,
  temp_lag1 = tempc.lag1,
  temp_lag2 = tempc.lag2,
  temp = tempc
))

fit <- stan(file="model.stan", data=model.data, iter=100, chains=1, verbose=TRUE)
#fit <- stan(file="simple.stan", data=list(N=100, v=rnorm(100)), iter=1000, chains=1)
#handle <- file("simple.cpp")
#writeLines(stanc(file="simple.stan")$cppcode, handle)
#close(handle)
