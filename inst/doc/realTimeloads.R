## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  out.width = "100%"
)

## ----setup--------------------------------------------------------------------
### Load library and example data ----
library(realTimeloads)
InputData <- realTimeloads::ExampleData
?realTimeloads::ExampleData

## ----Process and regress data-------------------------------------------------
### Assign list items to variables used in functions ------------------------ 
Site <- InputData$Site
ADCP <- InputData$ADCP
Echo_Intensity_Beam_1 <- InputData$Echo_Intensity
Echo_Intensity_Beam_2 <- InputData$Echo_Intensity # example code assumes backscatter is equal across beams; however, backscatter between beams will differ in practice 
Sonde <- InputData$Sonde
Height <- InputData$Height
Discharge <- InputData$Discharge
Sediment_Samples <- InputData$Sediment_Samples

### Process acoustic backscatter data  --------------------------------------
ADCPOutput <- realTimeloads::acoustic_backscatter_processing(Site,ADCP,Height,
                                                             Sonde,Echo_Intensity_Beam_1,Echo_Intensity_Beam_2)

### Compute estimate of analyte timeseries using https://doi.org/10.1029/2007WR006088 --------

# threshold (minutes) for interpolation of Surrogate to Analyte timeseries
threshold <- 30

# Surrogate "X" (e.g, acoustic backscatter and/or turbidity)
tx <- ADCPOutput$time
x <-ADCPOutput$mean_sediment_corrected_backscatter_beam_1_and_beam_2_dB

# Analyte "y" (e.g., TSS, NOx, etc)
ty <- Sediment_Samples$time
y <- Sediment_Samples$SSCpt_mg_per_liter

# interpolate surrogate onto analyte timeseries
# Randomly sample timeseries n times to simulate sampling that would occur in the field 
n <- 50
ind_calibration <-sample(1:length(ty),n,replace=FALSE)
calibration <- realTimeloads::surrogate_to_analyte_interpolation(tx,x,
                                                            ty[ind_calibration],y[ind_calibration],30)

# Specify calibration variable names for later storage in regression data
names(calibration)[grepl('surrogate',names(calibration))] <- 'SNR_dB'
names(calibration)[grepl('analyte',names(calibration))] <- 'SSCpt_mg_per_liter'

# compute bootstrap regression parameters per https://doi.org/10.1029/2007WR006088
fun_eq <- "log10(SSCpt_mg_per_liter) ~ SNR_dB"

Regression <- realTimeloads::bootstrap_regression(calibration,fun_eq)

# predict concentration timeseries with uncertainty
Surrogate <- data.frame(ADCPOutput$time,
                        ADCPOutput$mean_sediment_corrected_backscatter_beam_1_and_beam_2_dB)
colnames(Surrogate) <- c('time','SNR_dB')

Estimated_Concentration <- realTimeloads::estimate_timeseries(Surrogate,Regression)

## ----Compute load-------------------------------------------------------------
### Interpolate discharge onto surrogate time series (e.g., Backscatter t.s) ----
# All data in ExampleData are on the same time-step, however in practice this may not be the case
Q <- realTimeloads::linear_interpolation_with_time_limit(Discharge$time,
                                                         Discharge$Discharge_m_cubed_per_s,tx,threshold = 1)$x_interpolated

# compute dt (second) for load integration
dt =  c()
dt[2:length(tx)] <- as.numeric(difftime(tx[2:length(tx)],tx[1:length(tx)-1],units = "secs"))
dt[1] = median(dt,na.rm=TRUE) # assume time step 1 using median dt

# compute load (L) (kt) at each time "t"
# Estimated_Concentration$estimated_timeseries is a matrix with simulated timeseries drawn from Monte Carlo simulations on the bootstrapped regression parameters. Rows are simulations, columns are time. Methods are from https://doi.org/10.1029/2007WR006088. 
iters <- nrow(Regression$regression_parameters) # number of Monte Carlo simulations
Qsi =  matrix(NA, nrow = iters, ncol = length(x))
for (i in 1:iters) {
  Qsi[i,] <- Estimated_Concentration$estimated_timeseries[i,]*Q*dt*1e-9 # assumes concentration is mg/l and discharge is cubic meters per sec, dt is in seconds
}

## ----Compute uncertainty------------------------------------------------------
### Compute uncertainty on concentration and load timeseries ---------------
cQs = rowSums(Qsi,na.rm=TRUE) # total load for each iteration
quants <- c(0.0527, 0.1587, 0.5, 0.8414, 0.9473) # +/- 1 and 2 sigma and median (i.e., reported) estimate

Total_load_kt <- data.frame(t(quantile(cQs,quants,na.rm=TRUE)))
colnames(Total_load_kt) = c('minus_two_sigma_confidence','minus_one_sigma_confidence','median_confidence','plus_one_sigma_confidence','plus_two_sigma_confidence')

Reported_real_time_load_estimate <- Total_load_kt$median_confidence

# explicitly name timeseries with uncertainty for plotting below 
Analyte_concentration_timeseries_mg_per_liter <- Estimated_Concentration$estimated_timeseries_quantiles

Analyte_flux_timeseries_kt <- data.frame(t(apply(Qsi, 2 , quantile , probs = quants , 
                                                 na.rm = TRUE )))

colnames(Analyte_flux_timeseries_kt) = c('minus_two_sigma_confidence','minus_one_sigma_confidence','median_confidence',
                                         'plus_one_sigma_confidence','plus_two_sigma_confidence')

## ----Plot timeseries,fig.dim = c(8,6),dpi=300---------------------------------
### Compare estimate of concentration to actual ----

# actual loads (kt)
SSCxs <- Sediment_Samples$SSCxs_mg_per_liter
SSCpt <- Sediment_Samples$SSCpt_mg_per_liter
Qspt <- SSCpt*Q*dt*1e-9 # load from SSC measured at a point
Qsxs <- SSCxs*Q*dt*1e-9 # load from depth-averaged, velocity-weighted SSC

indp <- seq(from = 1, to = nrow(ADCP), by = 1) # vector for plotting subset of timeseries if desired 

plot(tx[indp],Analyte_concentration_timeseries_mg_per_liter$median_confidence[indp],
     col='red',type = "l",lwd= 2,xlab = "time (AEST)",ylab="Analyte concentration (mg/l)",
     main = "Estimated versus actual concentration",ylim = c(0,1500))
lines(tx[indp],Analyte_concentration_timeseries_mg_per_liter$minus_two_sigma_confidence[indp],
      col='grey',lty = c(5))
lines(tx[indp],Analyte_concentration_timeseries_mg_per_liter$plus_two_sigma_confidence[indp],
      col='grey',lty = c(5))
points(ty[ind_calibration],y[ind_calibration],
       col = 'black',pch = c(21))
lines(tx,Sediment_Samples$SSCpt_mg_per_liter,
      col='black',lwd= 1.5)

legend("topright",legend = c("Estimated concentration","Estimation uncertainty","Actual concentration used in regression","Actual concentration timeseries"),
       lty = c(1, 5, 0,1),col = c('red', 'grey', 'black', 'black'),pch = c(-1,-1,21,-1))

###  Compare estimate of flux to actual ----
plot(tx[indp],Analyte_flux_timeseries_kt$median_confidence[indp]/dt[indp]*1e3,
     col='red',type = "l",lwd= 2,xlab = "time (AEST)",ylab="Analyte flux (ton per second)",
     main = "Estimated versus actual flux",ylim = c(0,20))
lines(tx[indp],Analyte_flux_timeseries_kt$minus_two_sigma_confidence[indp]/dt[indp]*1e3,
      col='grey')
lines(tx[indp],Analyte_flux_timeseries_kt$plus_two_sigma_confidence[indp]/dt[indp]*1e3,
      col='grey')
points(tx[ind_calibration],Qspt[ind_calibration]/dt[ind_calibration]*1e3,col = 'black',
       pch = c(21))
lines(tx,Qspt/dt*1e3,col = 'black',lwd= 1.5)
legend("topright",legend = c("Estimated flux","Estimation uncertainty","Actual flux of data used in regression","Actual flux timeseries"),
       lty = c(1, 5, 0,1),col = c('red', 'grey', 'black', 'black'),pch = c(-1,-1,21,-1))

# check estimated load / modeled load
#mean(cQs)/sum(Qspt,na.rm=TRUE) # relative to Cpt (biased) load
#mean(cQs)/sum(Qsxs,na.rm=TRUE) # relative to Cxs (actual) load

Output <- list("time" = tx,"surrogate_timeseries_used_for_prediction_of_analyte"= df,"regression_data" = calibration,"regression_parameters_estimated_from_bootstrap_resampling" = Regression,"Analyte_concentration_timeseries_mg_per_liter"= Analyte_concentration_timeseries_mg_per_liter,"Dicharge" = Discharge,"Analyte_flux_timeseries_kt" =Analyte_flux_timeseries_kt)

## ----Compare total loads,fig.dim = c(8,8),dpi=300-----------------------------
### Compare total loads in barplot ----
# check ratios of estimated load to modeled load
#Total_load_kt$median_confidence/sum(Qspt,na.rm=TRUE) # estimated load relative to load at Cpt
#Total_load_kt$median_confidence/sum(Qsxs,na.rm=TRUE) # estimate total load relative to actual load from Cxs

loads <- c('Estimated load from SSCpt(dB)'= Total_load_kt$median_confidence,'Load from SSCpt' = sum(Qspt,na.rm=TRUE),'Load from SSCxs' = sum(Qsxs,na.rm=TRUE))

y <- c(Total_load_kt$median_confidence)
y0 <- c(Total_load_kt$plus_two_sigma_confidence)
y1 <- c(Total_load_kt$minus_two_sigma_confidence)
  
hb <- barplot(loads,main="Total load comparison",
        ylab="Total load (kt)",border=NA,ylim = c(0,8000))
arrows(x0=hb[1],y0=y0,y1=y1,angle=90,code=3,length=0.1)


## ----simulate missing data and impute data,fig.dim = c(8,8),dpi=300-----------

### Impute data ----
xo <- ADCPOutput$mean_sediment_corrected_backscatter_beam_1_and_beam_2_dB
# simulate 50% missing data
idata <- sample(which(is.finite(xo)),round(sum(is.finite(xo))*0.50),replace=FALSE)
x <- rep(NA,length(xo))
x[idata] <- xo[idata]
flow_ratio <- imputeTS::na_interpolation(Q/x)
Xreg <- cbind(Q,flow_ratio)
# random sampling of training set in impute_data() can generate warnings in decision tree algorithm 
# In impute_data(), ptrain = 1 can be set to preclude uncertainty estimation and decrease code run time. 
# ptrain=0.8 indicates that 80% of the finite data in x will be used in training regression trees and 20% of the data will be held-out for computing validation accuracy
suppressWarnings(Imputation <- impute_data(tx,x,Xreg,MC=10,ptrain=0.8))

ximputed <- Imputation$Imputed_data$x
ximputed[is.finite(x)] <- NA

plot(xo,ximputed,xlab = 'Backscatter (dB)', ylab = 'Imputed backscatter (dB)',ylim = c(min(xo,na.rm = T),max(xo,na.rm = T)),xlim = c(min(xo,na.rm = T),max(xo,na.rm = T)))
points(xo,Imputation$Imputed_data$x_at_minus_two_sigma_confidence,col='red')
points(xo,Imputation$Imputed_data$x_at_plus_two_sigma_confidence,col='blue')
lines(c(min(xo,na.rm=TRUE),max(xo,na.rm=TRUE)))
legend("topleft",legend = c("Median imputed value","Plus 2-sigma uncertainty on imputed value","Minus 2-sigma uncertainty on imputed value"), lty = c(0, 0,0),col = c('black', 'red', 'blue'),pch = c(21,21,21))



