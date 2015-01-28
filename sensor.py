#!/usr/bin/env python
import sys
import Adafruit_DHT
import requests
import os

SENSOR_PIN=14

# Try to grab a sensor reading.  Use the read_retry method which will retry up
# to 15 times to get a sensor reading (waiting 2 seconds between each retry).
humidity, temperature = Adafruit_DHT.read_retry(Adafruit_DHT.DHT22, SENSOR_PIN)

# Note that sometimes you won't get a reading and
# the results will be null (because Linux can't
# guarantee the timing of calls to read the sensor).  
# If this happens try again!
if humidity is not None and temperature is not None:
	print 'Temp={0:0.1f}*C  Humidity={1:0.1f}%'.format(temperature, humidity)
else:
	print 'Failed to get reading!'

data={"temp" : temperature, 
      "temp_scale" : "C", 
      "humidity_pct" : humidity,
      "access_token" : os.environ["BW_ACCESS_TOKEN"]
	}
resp = requests.post("http://54.165.110.137:88/", json=data,
		headers={"content-type" : "application/json"})
print(resp)
print(resp.text)
