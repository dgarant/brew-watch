data {
  int<lower=0> N;
  int<lower=0> delta_t_mins;
  vector[N] day_of_week;
  vector[N] hour_of_day;
  vector[N] sun_peak_delta_mins;
  vector[N] lux;
  vector[N] prev_external_temp;
  vector[N] prev_temp;
  vector[N] temp;
}
parameters {
  # when multiplied by the external temperature, gives the frequency of the heat/cool cycle
  real<lower=0> cycle_freq_mult;
  # multiplicative effect of sun position on light reading
  real<lower=0> sun_light_beta;
  real temp_noise;
  real lux_noise;
  real occ_lux;
  real cycle_amplitude;
  real occ_baseline_temp;
  real nonocc_baseline_temp;
  real sun_temp_beta;
}
model {
  
  temp_noise ~ normal(0, 3); # prior on noise in temperature measurement
  lux_noise ~ normal(0, 50); # prior on noise in lux measurement
  occ_lux ~ normal(300, 100); # prior on lux increase when lights are on
  cycle_amplitude ~ normal(2, 3); # prior on amplitude of heat/cool cycle (degrees C)
  occ_baseline_temp ~ normal(23, 3); # prior on median temperature when occupied (i.e. room thermostat setting)
  nonocc_baseline_temp ~ normal(20, 3); # prior on median temperature when unoccupied (i.e. building thermostat setting)
  sun_temp_beta ~ normal(5, 5); # multiplicative effect of sun position on room temperature
  
  # occupation is just a function of time and day
  if(hour_of_day >= 8 && hour_of_day <= 18 && day_of_week != 0 && day_of_week != 6) {
    occ ~ bernoulli(0.9);
  } else {
    occ ~ bernoulli(0.1);
  }
  
  lux ~ lognormal(sun_light_beta * delta_t_mins + (occ == 1 ? log(occ_lux) : 0), lux_noise) T[0,];
  
  # frequency of the heat/cool cycle
  cycle_freq <- cycle_freq_mult * prev_external_temp;
  
  baseline_term <- (occ == 1 ? occ_baseline : nonocc_baseline);
  sun_term <- sun_angle_beta * sun_peak_delta_mins;
  prev_cycle_pos <- (prev_temp - baseline_term - sun_term) / cycle_amplitude;
  temp ~ normal(
    baseline_term + 
      cycle_amplitude * sin(cycle_freq + asin(prev_cycle_pos) + delta_t_mins) +
      sun_term, noise);
}