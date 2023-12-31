% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/linear_interpolation_with_time_limit.R
\name{linear_interpolation_with_time_limit}
\alias{linear_interpolation_with_time_limit}
\title{Linearly interpolate timeseries time(x) onto new timesetep ti}
\usage{
linear_interpolation_with_time_limit(time, x, ti, threshold)
}
\arguments{
\item{time}{time for x (time, POSIXct)}

\item{x}{any quantity, for example discharge (double)}

\item{ti}{time where time(x) will be interpolated to (time, POSIXct)}

\item{threshold}{maximum duration where interpolation is allowed (hours)}
}
\value{
a data frame with time (ti), x interpolated from time(x) onto ti, and logical (ibad) if interpolation exceeded threshold
}
\description{
Linear interpolation limited by time since previous or following reading
}
\examples{
InputData <- realTimeloads::ExampleData
ADCP <- InputData$ADCP
Height <- InputData$Height
# Interpolate river height to ADCP time
time <- realTimeloads::ExampleData$Height$time
x <- realTimeloads::ExampleData$Height$Height_m
ti <-realTimeloads::ExampleData$ADCP$time
threshold <- 1
Output<- linear_interpolation_with_time_limit(time,x,ti,threshold)
}
\references{
Dowle M, and others (2023). data.table: Extension of 'data.frame'. https://cran.r-project.org/web/packages/data.table
}
\author{
Daniel Livsey (2023) ORCID: 0000-0002-2028-6128
}
