#' Return non-tidal signal in data after Rulh and Simpson (2005)
#'
#' Applies a Butterworth filter with a 30-hour stop period and a 40-hour pass period
#' @param time time for x (time, POSIXct)
#' @param x any quantity, for example discharge (double)
#' @returns non-tidal signal in x with data affected by filter ringing removed
#' @examples
#' time <- realTimeloads::ExampleData$Height$time
#' x <- realTimeloads::ExampleData$Height$Height_m
#' xf <- butterworth_tidal_filter(time,x)
#' @author Daniel Livsey (2023) ORCID: 0000-0002-2028-6128
#' @references
#' Ruhl, C. A., & Simpson, M. R. (2005). Computation of discharge using the index-velocity method in tidally affected areas (Vol. 2005). Denver: US Department of the Interior, US Geological Survey. https://pubs.usgs.gov/sir/2005/5004/sir20055004.pdf
#' @export
#'
butterworth_tidal_filter <- function(time,x) {
  # USGS filter for tides, Rulh and Simpson (2005)
  # https://pubs.usgs.gov/sir/2005/5004/
  # time, PosixCt (uniform timestep)
  # x, double
  #library(imputeTS)

  # From Rulh and Simpson 2005:
  # Use butterworth filter with
  # a 30-hour stop period and
  # a 40-hour pass period
  dt <- as.numeric(difftime(time[2],time[1]), units = "secs") # sampling timestep (seconds)
  #Rp and Rs values from:
  # https://au.mathworks.com/matlabcentral/answers/184520-how-to-design-a-lowpass-filter-for-ocean-wave-data-in-matlab
  Rp <- 1 # dB
  Rs <- 10 # dB
  Fs <- 1/(dt); # Sampling Frequency (Hz = samples/sec)
  Fn <- Fs/2; # Nyquist Frequency
  Wp <- (1/(30*60^2))/Fn # Filter Passband (Normalised)
  Ws <- (1/(40*60^2))/Fn # Filter Stopband (Normalised)
  bd <- signal::buttord(Wp,Ws,Rp,Rs)
  bw <- signal::butter(bd)

  # remove any data w/in 2 days of NaN per Rulh and Simpson (2005)
  n <- length(x)
  iNaN <- which(!is.finite(x)) # indices of NaNs in s
  x[iNaN] <- median(x,na.rm=TRUE) # Fill nans so filtfilt will filter entire signal
  xf <- x - signal::filtfilt(bw,x)

  # Remove Ringing at beginning and end of ts
  xf[1:(1+(3*(24*60^2/dt)))] = NaN
  xf[(n-(3*(24*60^2/dt))):n] = NaN

  # # Remove filter ringing in xf (removes 3 days near gaps)
  if (length(iNaN)>0) {
    for (i in 1:length(iNaN)) {
      #print(i)
      L = iNaN[i] - 3*(24*60^2/dt)
      U = iNaN[i] + 3*(24*60^2/dt)
      if (L < 1) L = 1

      if (U>length(x)) U <- n
      xf[L:U] = NaN;
    }

  }

  # x[iNaN] = NaN; # Reassign NaNs into signal

  return(xf)

}
