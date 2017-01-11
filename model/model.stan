data {
  int<lower=0> N;
  int<lower=0> delta_t_mins;
  int<lower=1,upper=7> day_of_week[N];
  int<lower=0,upper=24> hour_of_day[N];
  real sun_azimuth[N];
  real lux[N];
  real prev_external_temp[N];
  real prev_temp[N];
  real temp[N];
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
  real prev_beta;
  real<lower=0,upper=1> occ_in_work_hours_prob;
  real<lower=0,upper=1> occ_not_in_work_hours_prob;
}
model {
  
  real temp_means[N];
  real cycle_freq;
  real baseline_term;
  real sun_term;
  real prev_cycle_pos;
  int occ;
  int in_work_hours;
  real lux_term;
  real occprob;
  
  temp_noise ~ normal(0, 3); # prior on noise in temperature measurement
  lux_noise ~ normal(0, 50); # prior on noise in lux measurement
  occ_lux ~ normal(300, 100); # prior on lux increase when lights are on
  cycle_amplitude ~ normal(2, 3); # prior on amplitude of heat/cool cycle (degrees C)
  occ_baseline_temp ~ normal(23, 3); # prior on median temperature when occupied (i.e. room thermostat setting)
  nonocc_baseline_temp ~ normal(20, 3); # prior on median temperature when unoccupied (i.e. building thermostat setting)
  azimuth_beta ~ normal(3, 5); # multiplicative effect of sun position on room temperature
  azimuth_peak ~ normal(180, 50); # sun azimuth offset / normalizer
   // background knowledge about lab occupation
  occ_in_work_hours_prob ~ beta(5, 1);
  occ_not_in_work_hours_prob ~ beta(1, 5);

  for(i in 1:N) {
    in_work_hours = hour_of_day[i] >= 8 && hour_of_day[i] <= 18 && day_of_week[i] != 1 && day_of_week[i] != 7;
    if(in_work_hours) {
      lux[i] ~ normal(sun_light_beta * delta_t_mins + occ_lux, 3) T[0,];
      baseline_term = occ_baseline_temp;
    } else {
      lux[i] ~ normal(sun_light_beta * delta_t_mins, 3) T[0,];
      baseline_term =  nonocc_baseline_temp;
    }
    
    # frequency of the heat/cool cycle
    cycle_freq = cycle_freq_mult * prev_external_temp[i];
    
    sun_term = azimuth_beta * fabs(sun_azimuth[i] - azimuth_peak);
    #prev_cycle_pos = (prev_temp[i] - baseline_term - sun_term) / cycle_amplitude;
    #print("previous cycle position: ", prev_cycle_pos);
    #asin(prev_cycle_pos) + delta_t_mins
    # to do: need to figure something out for previous position in cycle
    temp_means[i] = (baseline_term + cycle_amplitude * sin(cycle_freq) + prev_beta * prev_temp[i] + sun_term);
     #print("computing temp mean ", i, ": ", temp_means[i]);
  }
  
  temp ~ normal(temp_means, 3);
}
