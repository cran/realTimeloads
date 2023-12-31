#' Near-field correction of Downing et al (1995)
#'
#' Computes dimensionless near-field correction
#' @param freq Frequency of sound (Hz)
#' @param c Speed of sound in water (m/s)
#' @param r range to cell center measured along-beam (m)
#' @param at Radius of ADCP transducer (m)
#' @returns Near-field correction (dimensionless)
#' @section Warning:
#' See various references cautioning use of near-field correction (e.g.,  https://doi.org/10.1002/2016WR019695)
#' @examples
#' InputData <- realTimeloads::ExampleData
#' Sonde<- InputData$Sonde
#' freq <- InputData$ADCP$Accoustic_Frequency_kHz[1]*1000
#' S <- ctd2sal(Sonde$Conductivity_uS_per_cm,Sonde$Water_Temperature_degC,Sonde$Pressure_dbar)
#' c <- speed_of_sound(S,Sonde$Water_Temperature_degC,Sonde$Pressure_dbar)
#' at <- InputData$ADCP$Transducer_radius_m
#' r <- seq(0.1,10,0.1)
#' psi <- near_field_correction(freq,c[1],r,at[1])
#' @references
#' Downing, A., Thorne, P. D., & Vincent, C. E. (1995). Backscattering from a suspension in the near field of a piston transducer. The Journal of the Acoustical Society of America, 97(3), 1614-1620.
#' @author Daniel Livsey (2023) ORCID: 0000-0002-2028-6128
#' @export
#'
near_field_correction <- function(freq,c,r,at) {
  # Computes near-field correction psi (dimensionless) using eq. from Thorne
  # and Hurther 2014
  # Inputs:
  # freq: frequency of sound (Hz)
  # c: speed of sound in water (m/s)
  # r: distance from transducer (m)
  # at: transducer radius (m)
  # Outputs:
  # psi, near-field correction (dimensionless)
  # Daniel Livsey, 2023
  k=2*pi*freq/c
  Rstar=r/((k/2)*at^2)
  psi = 1/(1 - 1/(1+1.35*Rstar+(2.5*Rstar)^3.2))
  return(psi)
}
