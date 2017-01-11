library(RSQLite)
library(rstan)
library(insol)
library(plyr)
setwd("C:/repos/brew-watch/model")
conn <- dbConnect(RSQLite::SQLite(), "data.s3db")
result <- dbSendQuery(conn, "select * from measurement")
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

prev.ext.temp <- measurements.with.lux[1:(nrow(measurements.with.lux) - 1), ]$ext.temp
prev.temp <- measurements.with.lux[1:(nrow(measurements.with.lux) - 1), ]$tempc
model.data <- with(measurements.with.lux[2:nrow(measurements.with.lux), ], list(
  N = length(date),
  delta_t_mins = 10,
  day_of_week = dow,
  hour_of_day = hour,
  sun_azimuth = azimuth,
  lux = lux,
  prev_external_temp = prev.ext.temp,
  prev_temp = prev.temp,
  temp = tempc
))

rstan_options(auto_write = TRUE)
options(mc.cores = parallel::detectCores())
fit <- stan(file="model.stan", data=model.data, iter=1000, chains=4, verbose=TRUE)
#fit <- stan(file="simple.stan", data=list(N=100, v=rnorm(100)), iter=1000, chains=1)
#handle <- file("simple.cpp")
#writeLines(stanc(file="simple.stan")$cppcode, handle)
#close(handle)
