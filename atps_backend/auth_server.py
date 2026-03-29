from flask import Flask, request, jsonify
from pymongo import MongoClient
from flask_cors import CORS
import datetime
import math
from bson import ObjectId

# ================= APP SETUP =================
app = Flask(__name__)
CORS(app)

# ================= DATABASE CONNECTION =================
MONGO_URI = "mongodb+srv://admin:admin123@cluster0.oiagpxv.mongodb.net/?appName=Cluster0"

try:
    client = MongoClient(MONGO_URI)
    db = client.get_database("atps_db")
    users_collection = db.users
    logs_collection = db.emergency_logs
    # Stores manual signal overrides for junction controllers to poll
    signals_collection = db.junction_signals
    authorized_admins = db.authorized_admins
    guest_locations = db.guest_locations
    guest_locations.create_index("timestamp", expireAfterSeconds=300)
    print("✅ Connected to ATPS Central Control Server")
except Exception as e:
    print(f"❌ Connection Error: {e}")


# ================= 1. ADD NEW CONTROLLED SIGNAL =================
@app.route('/api/admin/add_signal', methods=['POST'])
def add_signal():
    data = request.json

    new_signal = {
        "junction_id": data.get('junction_id').upper(),
        "junction_name": data.get('junction_name'),
        "landmark": data.get('landmark'),
        "lat": float(data.get('lat')),
        "lon": float(data.get('lon')),
        "esp32_id": data.get('esp32_id'),
        "trigger_radius": int(data.get('trigger_radius', 500)),
        "green_hold_time": int(data.get('green_hold_time', 30)),
        "mode": data.get('mode', 'AUTO'),
        "current_status": "RED",
        "last_updated": datetime.datetime.utcnow()
    }

    if signals_collection.find_one({"junction_id": new_signal['junction_id']}):
        return jsonify({"success": False, "message": "Junction ID already exists"}), 400

    signals_collection.insert_one(new_signal)
    return jsonify({"success": True, "message": "Signal added successfully"}), 201

# ================= HELPER: DISTANCE CALCULATION =================
def calculate_distance(lat1, lon1, lat2, lon2):
    # Haversine formula to calculate distance in kilometers
    R = 6371 
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

# ================= 2. GPS TRACKING & AUTO-PRIORITY =================
@app.route('/api/update_location', methods=['POST'])
def update_location():
    data = request.json
    unit_id = data.get('unit_id')
    amb_lat = float(data.get('lat'))
    amb_lon = float(data.get('lon'))

    active_signals = list(signals_collection.find({"mode": "AUTO"}))

    nearest_signal = None
    min_dist = 999.0

    for signal in active_signals:
        dist = calculate_distance(amb_lat, amb_lon, signal['lat'], signal['lon'])

        if dist < min_dist:
            min_dist = dist
            nearest_signal = signal

    if nearest_signal:
        radius_km = nearest_signal['trigger_radius'] / 1000

        if min_dist < radius_km:
            print(f"🚨 Priority Activated: {unit_id} near {nearest_signal['junction_name']}")

            signals_collection.update_one(
                {"junction_id": nearest_signal['junction_id']},
                {"$set": {
                    "current_status": "GREEN",
                    "last_updated": datetime.datetime.utcnow()
                }}
            )

            return jsonify({
                "unit_id": unit_id,
                "nearest_junction": nearest_signal['junction_name'],
                "distance_km": round(min_dist, 2),
                "command": "SET_GREEN",
                "target_esp32": nearest_signal['esp32_id'],
                "hold_time": nearest_signal['green_hold_time']
            }), 200

        return jsonify({
            "unit_id": unit_id,
            "nearest_junction": nearest_signal['junction_name'],
            "distance_km": round(min_dist, 2),
            "command": "KEEP_NORMAL"
        }), 200

    return jsonify({
        "unit_id": unit_id,
        "nearest_junction": None,
        "distance_km": None,
        "command": "KEEP_NORMAL"
    }), 200
# ================= GUEST LOCATION TRACKING =================
@app.route('/api/guest/update_location', methods=['POST'])
def guest_update():
    data = request.json

    guest_id = data.get('guest_id')
    lat = float(data.get('lat', 0))
    lon = float(data.get('lon', 0))

    guest_locations.update_one(
        {"guest_id": guest_id},
        {"$set": {
            "lat": lat,
            "lon": lon,
            "timestamp": datetime.datetime.utcnow()
        }},
        upsert=True
    )

    return jsonify({"success": True, "message": "Guest location updated"}), 200

# ================= 2. EMERGENCY REQUESTS (AUTO-APPROVE) =================
@app.route('/api/request_priority', methods=['POST'])
def request_priority():
    data = request.json
    # Requests are APPROVED by default for your selected drivers
    new_request = {
        "unit_id": data.get('unit_id'),
        "driver_name": data.get('driver_name'),
        "start": data.get('start'),
        "destination": data.get('destination'),
        "phone": data.get('phone'),
        "status": "APPROVED", 
        "timestamp": datetime.datetime.utcnow()
    }
    
    result = logs_collection.insert_one(new_request)
    return jsonify({
        "success": True, 
        "request_id": str(result.inserted_id), 
        "status": "APPROVED"
    }), 201

# ================= 3. ADMIN OVERRIDES & SIGNAL CONTROL =================
@app.route('/api/admin/update_status', methods=['POST'])
def update_status():
    data = request.json
    req_id = data.get('request_id')
    new_status = data.get('status') # Admin can change to 'DENIED' or 'COMPLETED'

    logs_collection.update_one(
        {"_id": ObjectId(req_id)}, 
        {"$set": {"status": new_status}}
    )
    return jsonify({"success": True, "message": f"Status updated to {new_status}"}), 200

@app.route('/api/admin/signal_override', methods=['POST'])
def signal_override():

    data = request.json
    junction_id = data.get('junction_id')
    color = data.get('color')   # "GREEN" or "RED"

    signals_collection.update_one(
        {"junction_id": junction_id},
        {"$set": {
            "mode": "MANUAL",
            "current_status": color,
            "manual_color": color,
            "last_updated": datetime.datetime.utcnow()
        }},
        upsert=False
    )

    return jsonify({
        "success": True,
        "message": f"Signal {junction_id} forced to {color} in MANUAL mode"
    }), 200

@app.route('/api/admin/signals', methods=['GET'])
def get_all_signals():
    try:
        signals = list(signals_collection.find({}, {"_id": 0}).sort("junction_id", 1))
        for s in signals:
            s['battery_level'] = s.get('battery_level', 100)
            if 'last_updated' not in s:
                s['last_updated'] = datetime.datetime.utcnow()
        return jsonify(signals), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
    
@app.route('/api/admin/requests', methods=['GET'])
def get_active_requests():
    try:
        time_limit = datetime.datetime.utcnow() - datetime.timedelta(days=7)

        requests_query = list(logs_collection.find({
            "timestamp": {"$gt": time_limit}
        }, {
            "_id": 1,
            "unit_id": 1,
            "driver_name": 1,
            "status": 1,
            "destination": 1,
            "phone": 1
        }).sort("timestamp", -1))

        for req in requests_query:
            req['id'] = str(req.pop('_id'))

        return jsonify(requests_query), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500    
    
@app.route('/api/admin/stats', methods=['GET'])
def get_dashboard_stats():
    try:
        total_units = users_collection.count_documents({"role": "DRIVER"})
        active_emergencies = logs_collection.count_documents({"status": "APPROVED"})
        total_signals = signals_collection.count_documents({})

        return jsonify({
            "active_emergencies": active_emergencies,
            "registered_units": total_units,
            "available_units": total_units - active_emergencies,
            "total_signals": total_signals
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500    

# ================= 4. AUTH & UNIT MANAGEMENT =================
@app.route('/api/signup', methods=['POST'])
def signup():
    data = request.json
    username = data.get('username')
    role = data.get('role', 'DRIVER').upper()
    unit_id = data.get('unit_id', '').upper()

    if users_collection.find_one({"username": username}):
        return jsonify({"success": False, "message": "Username taken"}), 400

    # Role validation logic
    if role == "ADMIN":
        if not authorized_admins.find_one({"unit_id": unit_id, "active": True}):
            return jsonify({"success": False, "message": "Unauthorized Admin ID"}), 403
    elif role == "DRIVER" and not unit_id.startswith("AMB-"):
        return jsonify({"success": False, "message": "Invalid Ambulance ID"}), 400

    new_user = {
        "name": data.get('name'),
        "username": username,
        "password": data.get('password'),
        "unit_id": unit_id,
        "phone": data.get('phone'),
        "role": role,
        "created_at": datetime.datetime.utcnow()
    }
    users_collection.insert_one(new_user)
    return jsonify({"success": True}), 201

@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    user = users_collection.find_one({"username": data.get('username'), "password": data.get('password')})
    if user:
        return jsonify({
            "success": True, 
            "user": {
                "name": user['name'], 
                "unit_id": user['unit_id'], 
                "role": user['role'], 
                "phone": user.get('phone')
            }
        }), 200
    return jsonify({"success": False, "message": "Invalid credentials"}), 401

@app.route('/api/units', methods=['GET'])
def get_units():
    # Returns all drivers with their contact info for the Admin Dashboard
    drivers = list(users_collection.find({"role": "DRIVER"}, {"_id": 0, "name": 1, "unit_id": 1, "phone": 1}))
    for d in drivers:
        d['battery_level'] = d.get('battery_level', 100)
        if 'last_updated' not in d:
            d['last_updated'] = datetime.datetime.utcnow()
    return jsonify(drivers), 200

# ================= RUN SERVER =================
if __name__ == '__main__':
    # host='0.0.0.0' allows external ESP32 and mobile app access
    app.run(host='0.0.0.0', port=5000, debug=True)