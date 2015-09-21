import flask
from flask import Flask, g, abort, request
import sqlite3
import datetime
import os
import logging
from logging.handlers import RotatingFileHandler
app = Flask(__name__)

file_handler = RotatingFileHandler(os.path.join(os.path.dirname(__file__), "applog.txt"), 
			maxBytes=1024 * 1024 * 1024, backupCount=3)
file_handler.setLevel(logging.WARNING)
app.logger.addHandler(file_handler)

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
	
@app.route("/", methods=["GET"])
def home():
	measurements = query_db("select timestamp, temperature_f, humidity_pct from measurement")
	structured_data = []
	for m in measurements:
		structured_data.append({"timestamp" : m[0], "temperature_f" : m[1], "humidity_pct" : m[2]})
		
	return flask.jsonify(results=structured_data)

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

	db = get_db()
	cursor = db.cursor()
	cursor.execute("insert into measurement (timestamp, temperature_f, humidity_pct) values (?, ?, ?)", 
		(datetime.datetime.now().isoformat(), temperature_f, measurement_info["humidity_pct"]))
	db.commit()
	cursor.close()
	
	return flask.jsonify({"status" : "success"})

if __name__ == "__main__":
	app.run(host="0.0.0.0")

