data {
  int<lower=0> N;
  int<lower=0> delta_t_mins;
  int<lower=1,upper=7> day_of_week[N];
  int<lower=0,upper=24> hour_of_day[N];
  real sun_azimuth[N];
  real lux[N];
  real prev_external_temp[N];
  real temp_lag2[N];
  real temp_lag1[N];
  real temp[N];
}
parameters {
  # multiplicative effect of sun position on light reading
  real sun_light_beta;
  real<lower=0> temp_noise;
  real<lower=0> lux_noise;
  real occ_lux;
  real occ_baseline_temp;
  real nonocc_baseline_temp;
  real lux_beta;
  real azimuth_peak;
  real beta_sign;
  real beta_slope;
  real thermostat_deviation;
}
model {
  
  real temp_means[N];
  real baseline_term;
  int in_work_hours;
  real lux_term;
  real min_dev;
  real max_dev;
  
  temp_noise ~ normal(1, 5); # prior on noise in temperature measurement
  lux_noise ~ normal(25, 100); # prior on noise in lux measurement
  occ_lux ~ normal(300, 100); # prior on lux increase when lights are on
  occ_baseline_temp ~ normal(23, 3); # prior on median temperature when occupied (i.e. room thermostat setting)
  nonocc_baseline_temp ~ normal(20, 3); # prior on median temperature when unoccupied (i.e. building thermostat setting)
  lux_beta ~ normal(3, 5); # multiplicative effect of sun position on room temperature
  azimuth_peak ~ normal(180, 50); # sun azimuth offset / normalizer
  thermostat_deviation ~ normal(5, 10);

  for(i in 1:N) {
    in_work_hours = hour_of_day[i] >= 8 && hour_of_day[i] <= 18 && day_of_week[i] != 1 && day_of_week[i] != 7;
    if(in_work_hours) {
      lux[i] ~ normal(sun_light_beta * (sun_azimuth[i] - azimuth_peak) + occ_lux, lux_noise) T[0, ];
      baseline_term = occ_baseline_temp;
    } else {
      lux[i] ~ normal(sun_light_beta * (sun_azimuth[i] - azimuth_peak), lux_noise) T[0, ];
      baseline_term =  nonocc_baseline_temp;
    }
    min_dev = baseline_term - thermostat_deviation;
    max_dev = baseline_term + thermostat_deviation;
    
    temp_means[i] = fmin(max_dev, fmax(min_dev, (baseline_term + beta_sign * sign(temp_lag1[i] - temp_lag2[i]) + 
      beta_slope * (temp_lag1[i] - temp_lag2[i])  + lux_beta * lux[i])));
    print("computing temp mean ", i, ": ", temp_means[i]);
  }
  
  temp ~ normal(temp_means, temp_noise);
}
