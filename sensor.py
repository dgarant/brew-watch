#!/usr/bin/env python
import sys
import Adafruit_DHT
import requests
import os
import RPi.GPIO as GPIO
from w1thermsensor import W1ThermSensor
from tentacle_pi.TSL2561 import TSL2561
import time

SENSOR_PIN=14
POWERSWITCH_PIN=15

# the temperature at which the heating pad will be activated
TEMPERATURE_ON_THRESHOLD=71
TEMPERATURE_OFF_THRESHOLD=73

def read_probe_temp():
    sensor = W1ThermSensor()
    return sensor.get_temperature(W1ThermSensor.DEGREES_F)
#print(read_probe_temp())

# Try to grab a sensor reading.  Use the read_retry method which will retry up
# to 15 times to get a sensor reading (waiting 2 seconds between each retry).
humidity, temperature = Adafruit_DHT.read_retry(Adafruit_DHT.DHT22, SENSOR_PIN)
f_temperature_bb = temperature * 9/5. + 32

# Note that sometimes you won't get a reading and
# the results will be null (because Linux can't
# guarantee the timing of calls to read the sensor).  
# If this happens try again!
if humidity is not None and temperature is not None:
	print('Breadboard: Temp={0:0.1f}*F  Humidity={1:0.1f}%'.format(f_temperature_bb, humidity))
	#print("Probe: Temp={0:0.1f}*F".format(f_temperature_probe))
else:
	print 'Failed to get reading!'

action = None
pin_15_on = None
if False: # disabling heating pad
    GPIO.setwarnings(False)
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(15, GPIO.OUT)
    with open("/sys/class/gpio/gpio15/value") as pin:
	    pin_15_on = int(pin.read(1))

    if f_temperature_bb >= TEMPERATURE_OFF_THRESHOLD and pin_15_on:
	    print("Turning off heat")
	    action = "off"
	    GPIO.output(15, False)	
    elif f_temperature_bb <= TEMPERATURE_ON_THRESHOLD and not pin_15_on:
	    print("Turning on heat")
	    action = "on"
	    GPIO.output(15, True)	

tsl = TSL2561(0x39,"/dev/i2c-1")
tsl.enable_autogain()
tsl.set_time(0x00)
# take 3 lux readings and compute the median
lux_readings = []
for i in range(3):
    lux_readings.append(tsl.lux())
    time.sleep(0.1)
lux_median = sorted(lux_readings)[1]
print("Lux: {0}".format(lux_median))

data={"temp" : temperature, 
      "temp_scale" : "C", 
      "action" : action,
      "is_heat_on" : pin_15_on,
      "humidity_pct" : humidity,
      "lux" : lux_median,
      "access_token" : os.environ["BW_ACCESS_TOKEN"]
	}
print(data)
resp = requests.post("http://temp.garantanalytics.com/", json=data,
		headers={"content-type" : "application/json"})
print(resp)
print(resp.text)
