import flask
from flask import render_template
from flask import Flask, g, abort, request
import sqlite3
import datetime
import os
import logging
from dateutil import parser as dparser
from logging.handlers import RotatingFileHandler
from logging import StreamHandler
app = Flask(__name__)

file_handler = RotatingFileHandler(os.path.join(os.path.dirname(__file__), "applog.txt"), 
			maxBytes=1024 * 1024 * 1024, backupCount=3)
file_handler.setLevel(logging.WARNING)
app.logger.addHandler(file_handler)

console_logger = StreamHandler()
app.logger.addHandler(console_logger)


DATABASE=os.path.join(os.path.dirname(__file__), "data.s3db")

def get_db():
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = connect_to_database()
    return db

def query_db(query, args=(), one=False):
    cur = get_db().execute(query, args)
    rv = cur.fetchall()
    cur.close()
    return (rv[0] if rv else None) if one else rv

@app.teardown_appcontext
def close_connection(exception):
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

def connect_to_database():
	return sqlite3.connect(DATABASE)
	
@app.route("/measurements", methods=["GET"])
def measurements():
	start_date = dparser.parse(request.args.get("start-date", (datetime.datetime.now() - datetime.timedelta(days=5)).isoformat()))
	measurements = query_db("select timestamp, temperature_f, probe_temperature_f, humidity_pct, is_heat_on, lux " + 
						"from measurement where timestamp > ?", [start_date.isoformat()])
	structured_data = []
	for m in measurements:
		structured_data.append({"timestamp" : m[0], "temperature_f" : m[1], "probe_temperature_f" : m[2], 
                                        "humidity_pct" : m[3], "is_heat_on" : m[4], "lux" : m[5]})
		
	return flask.jsonify(results=structured_data)

@app.route("/", methods=["GET"])
def home():
	return render_template("home.html")	

@app.route("/", methods=["POST"])
def add_measurement():
	expected_access_token=request.environ["BW_ACCESS_TOKEN"]

	measurement_info = request.json
	access_token = measurement_info["access_token"]
	if access_token != expected_access_token:
		abort(403)
	if measurement_info["temp_scale"].lower() == "c":
		temperature_f = measurement_info["temp"] * 1.8 + 32
	else:
		temperature_f = measurement_info["temp"]

	if measurement_info["probe_temp_scale"].lower() == "c":
		probe_temperature_f = measurement_info["probe_temp"] * 1.8 + 32
	else:
		probe_temperature_f = measurement_info["probe_temp"]

	db = get_db()
	cursor = db.cursor()
	cursor.execute("insert into measurement (timestamp, temperature_f, probe_temperature_f, humidity_pct, is_heat_on, lux) values (?, ?, ?, ?, ?, ?)", 
		(datetime.datetime.now().isoformat(), temperature_f, probe_temperature_f,
                    measurement_info["humidity_pct"], measurement_info["is_heat_on"], measurement_info["lux"]))
	db.commit()
	cursor.close()
	
	return flask.jsonify({"status" : "success"})

if __name__ == "__main__":
	app.run(host="0.0.0.0")

