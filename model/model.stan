data {
  int<lower=0> N;
  int<lower=0> delta_t_mins;
  int day_of_week[N];
  int hour_of_day[N];
  real sun_azimuth[N];
  real lux[N];
  real prev_external_temp[N];
  real prev_temp[N];
  real temp[N];
}
transformed data {
  int in_work_hours[N];
  real occ_param[N];
  for(i in 1:N) {
    in_work_hours[i] = hour_of_day[i] >= 8 && hour_of_day[i] <= 18 && day_of_week[i] != 1 && day_of_week[i] != 7;
    occ_param[i] = in_work_hours[i] ? 0.9 : 0.1; // background knowledge about lab occupation
  }
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
  real azimuth_beta;
  real azimuth_peak;
}
model {
  
  real temp_means[N];
  real cycle_freq[N];
  real baseline_term[N];
  real sun_term[N];
  real prev_cycle_pos[N];
  int occ[N];
  real lux_term[N];
  
  temp_noise ~ normal(0, 3); # prior on noise in temperature measurement
  lux_noise ~ normal(0, 50); # prior on noise in lux measurement
  occ_lux ~ normal(300, 100); # prior on lux increase when lights are on
  cycle_amplitude ~ normal(2, 3); # prior on amplitude of heat/cool cycle (degrees C)
  occ_baseline_temp ~ normal(23, 3); # prior on median temperature when occupied (i.e. room thermostat setting)
  nonocc_baseline_temp ~ normal(20, 3); # prior on median temperature when unoccupied (i.e. building thermostat setting)
  azimuth_beta ~ normal(3, 5); # multiplicative effect of sun position on room temperature
  azimuth_peak ~ normal(180, 50); # sun azimuth offset / normalizer
  
  #occ ~ bernoulli(occ_prob);

  for(i in 1:N) {
    occ[i] = 1;
    lux_term[i] = (occ[i] ? occ_lux : 0.0);
    lux[i] ~ normal(sun_light_beta * delta_t_mins + lux_term[i], 3) T[0,];
    
    # frequency of the heat/cool cycle
    cycle_freq[i] = cycle_freq_mult * prev_external_temp[i];
    baseline_term[i] = (occ[i] ? occ_baseline_temp : nonocc_baseline_temp);
    
    sun_term[i] = azimuth_beta * fabs(sun_azimuth[i] - azimuth_peak);
    prev_cycle_pos[i] = (prev_temp[i] - baseline_term[i] - sun_term[i]) / cycle_amplitude;
    temp_means[i] = (baseline_term[i] + cycle_amplitude * 
     sin(cycle_freq[i] + asin(prev_cycle_pos[i]) + delta_t_mins) + sun_term[i]);
  }
  
  temp ~ normal(temp_means, 3);
}
