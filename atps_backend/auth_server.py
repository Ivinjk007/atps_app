from flask import Flask, request, jsonify
from pymongo import MongoClient
from flask_cors import CORS
import datetime
import math
from bson import ObjectId
import threading
import time
import os

# ================= APP SETUP =================
app = Flask(__name__)
CORS(app)

# ================= DATABASE CONNECTION =================
MONGO_URI = "mongodb+srv://admin:admin123@cluster0.oiagpxv.mongodb.net/?appName=Cluster0"

@app.route('/')
def home():
    return jsonify({"message": "ATPS Backend is running"}), 200


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
    # In-memory ambulance tracker
ambulance_tracker = {}


# ================= 1. ADD NEW CONTROLLED SIGNAL =================
@app.route('/api/admin/add_signal', methods=['POST'])
def add_signal():
    data = request.json

    new_signal = {
        "junction_id":    data.get('junction_id').upper(),
        "junction_name":  data.get('junction_name'),
        "landmark":       data.get('landmark'),
        "esp32_id":       data.get('esp32_id'),
        "trigger_radius": int(data.get('trigger_radius', 500)),
        "green_hold_time": int(data.get('green_hold_time', 30)),
        "mode":           data.get('mode', 'AUTO'),
        "current_status": "RED",
        "active_light":   1,
        "manual_color":   None,
        "last_updated":   datetime.datetime.utcnow(),
        "lights": [
            {"light_id": 1, "direction": "NORTH", "lat": float(data.get('lat_1', 0)), "lon": float(data.get('lon_1', 0))},
            {"light_id": 2, "direction": "EAST",  "lat": float(data.get('lat_2', 0)), "lon": float(data.get('lon_2', 0))},
            {"light_id": 3, "direction": "SOUTH", "lat": float(data.get('lat_3', 0)), "lon": float(data.get('lon_3', 0))},
            {"light_id": 4, "direction": "WEST",  "lat": float(data.get('lat_4', 0)), "lon": float(data.get('lon_4', 0))},
        ]
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
    data     = request.json
    username = data.get('username')
    amb_lat  = float(data.get('lat'))
    amb_lon  = float(data.get('lon'))
    now      = datetime.datetime.utcnow()

    # ── 1. CHECK IF DRIVER HAS ACTIVE APPROVED REQUEST ──
    log = logs_collection.find_one(
        {"username": username, "status": "APPROVED"},
        sort=[("timestamp", -1)]
    )

    if not log:
        ambulance_tracker[username] = {
            "lat":           amb_lat,
            "lon":           amb_lon,
            "timestamp":     now,
            "priority":      None,
            "requested_at":  None,
            "target_light":  None,
            "prev_distance": None,
        }
        return jsonify({
            "username": username,
            "command":  "KEEP_NORMAL",
            "message":  "No active request — location tracked only"
        }), 200

    priority     = log.get('priority', 'Non-Critical')
    requested_at = log.get('timestamp', now)

    # ── 2. SPEED CALCULATION ──
    speed_kmh = 30.0
    prev = ambulance_tracker.get(username)

    if prev:
        time_diff = (now - prev['timestamp']).total_seconds()
        if time_diff > 0:
            dist_moved = calculate_distance(
                prev['lat'], prev['lon'], amb_lat, amb_lon
            )
            speed_kmh = (dist_moved / time_diff) * 3600
            if speed_kmh < 1:
                speed_kmh = 30.0

    # ── 3. FIND NEAREST LIGHT ──
    junctions = list(signals_collection.find({}))

    nearest_junction = None
    nearest_light_id = 1
    min_dist         = 999.0

    for junction in junctions:
        lights = junction.get('lights', [])
        for light in lights:
            dist = calculate_distance(amb_lat, amb_lon, light['lat'], light['lon'])
            if dist < min_dist:
                min_dist         = dist
                nearest_junction = junction
                nearest_light_id = light['light_id']

    # ── 4. UPDATE TRACKER ──
    ambulance_tracker[username] = {
        "lat":           amb_lat,
        "lon":           amb_lon,
        "timestamp":     now,
        "priority":      priority,
        "requested_at":  requested_at,
        "target_light":  nearest_light_id,
        "prev_distance": min_dist,
    }

    if not nearest_junction:
        return jsonify({
            "username": username,
            "command":  "KEEP_NORMAL",
            "eta":      None,
        }), 200

    radius_km = nearest_junction['trigger_radius'] / 1000

    # ── 5. CHECK IF AMBULANCE HAS PASSED ──
    if prev:
        prev_target = prev.get('target_light')
        prev_dist   = prev.get('prev_distance', min_dist)

        if prev_dist < radius_km and min_dist > prev_dist:
            print(f"✅ {username} passed — resuming AUTO")
            priority_junction = signals_collection.find_one(
                {"priority_unit": username}
            )
            if priority_junction:
                signals_collection.update_one(
                    {"_id": priority_junction["_id"]},
                    {"$set": {
                        "mode":           "AUTO",
                        "current_status": "RED",
                        "active_light":   prev_target or 1,
                        "priority_unit":  None,
                        "last_updated":   now
                    }}
                )
            ambulance_tracker.pop(username, None)
            return jsonify({
                "username": username,
                "command":  "KEEP_NORMAL",
                "message":  "Ambulance passed — AUTO resumed"
            }), 200

    # ── 6. WITHIN TRIGGER RADIUS? ──
    if min_dist >= radius_km:
        return jsonify({
            "username":         username,
            "nearest_junction": nearest_junction['junction_name'],
            "distance_km":      round(min_dist, 3),
            "command":          "KEEP_NORMAL",
            "eta_seconds":      None,
        }), 200

    # ── 7. ETA CALCULATION ──
    speed_ms  = speed_kmh / 3.6
    dist_m    = min_dist * 1000
    eta_secs  = (dist_m / speed_ms) if speed_ms > 0 else 999

    print(f"🚑 {username} | Priority: {priority} | Distance: {round(dist_m)}m | Speed: {round(speed_kmh)}km/h | ETA: {round(eta_secs)}s")

    # ── 8. PRIORITY & FCFS CHECK ──
    current_junction = signals_collection.find_one(
        {"junction_id": nearest_junction['junction_id']}
    )
    current_mode = current_junction.get('mode', 'AUTO')

    if current_mode == 'PRIORITY':
        active_unit = current_junction.get('priority_unit')
        if active_unit and active_unit != username:
            active_info      = ambulance_tracker.get(active_unit, {})
            active_priority  = active_info.get('priority', 'Non-Critical')
            active_requested = active_info.get('requested_at', now)

            if priority == 'Non-Critical' and active_priority == 'Critical':
                return jsonify({
                    "username":    username,
                    "command":     "KEEP_NORMAL",
                    "message":     "Higher priority ambulance has control",
                    "eta_seconds": round(eta_secs)
                }), 200

            if priority == active_priority and requested_at > active_requested:
                return jsonify({
                    "username":    username,
                    "command":     "KEEP_NORMAL",
                    "message":     "Earlier ambulance has control (FCFS)",
                    "eta_seconds": round(eta_secs)
                }), 200

    # ── 9. SET GREEN WHEN ETA <= 2 SECONDS ──
    if eta_secs <= 2:
        print(f"🚨 PRIORITY: {username} arriving in {round(eta_secs)}s — Light {nearest_light_id} GREEN")
        signals_collection.update_one(
            {"junction_id": nearest_junction['junction_id']},
            {"$set": {
                "mode":           "PRIORITY",
                "current_status": "GREEN",
                "active_light":   nearest_light_id,
                "priority_unit":  username,
                "last_updated":   now
            }}
        )
        return jsonify({
            "username":         username,
            "nearest_junction": nearest_junction['junction_name'],
            "distance_km":      round(min_dist, 3),
            "command":          "SET_GREEN",
            "target_light":     nearest_light_id,
            "target_esp32":     nearest_junction['esp32_id'],
            "eta_seconds":      round(eta_secs),
            "speed_kmh":        round(speed_kmh, 1),
        }), 200

    # ── 10. APPROACHING BUT ETA > 2s ──
    return jsonify({
        "username":         username,
        "nearest_junction": nearest_junction['junction_name'],
        "distance_km":      round(min_dist, 3),
        "command":          "KEEP_NORMAL",
        "eta_seconds":      round(eta_secs),
        "speed_kmh":        round(speed_kmh, 1),
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
        "username":    data.get('username'),
        "driver_name": data.get('driver_name'),
        "start": data.get('start'),
        "destination": data.get('destination'),
        "phone": data.get('phone'),
        "priority": data.get('priority', 'Non-Critical'),
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

@app.route('/api/driver/request_status/<unit_id>', methods=['GET'])
def get_driver_status(unit_id):
    log = logs_collection.find_one(
        {"unit_id": unit_id},
        sort=[("timestamp", -1)]
    )
    if not log:
        return jsonify({"status": "NONE"}), 200
    
    return jsonify({
        "status": log.get("status", "NONE"),
        "request_id": str(log["_id"])
    }), 200

@app.route('/api/admin/delete_request', methods=['POST'])
def delete_request():
    data = request.json
    req_id = data.get('request_id')
    logs_collection.delete_one({"_id": ObjectId(req_id)})
    return jsonify({"success": True, "message": "False alarm deleted"}), 200

@app.route('/api/admin/signal_override', methods=['POST'])
def signal_override():
    data = request.json
    junction_id = data.get('junction_id')
    color = data.get('color')   # "GREEN", "RED", "YELLOW", or "AUTO"
    now_utc = datetime.datetime.utcnow()

    if color == "AUTO":
        signals_collection.update_one(
            {"junction_id": junction_id},
            {"$set": {
                "mode": "AUTO",
                "last_updated": now_utc
            }}
        )
        msg_mode = "AUTO"
    else:
        signals_collection.update_one(
            {"junction_id": junction_id},
            {"$set": {
                "mode": "MANUAL",
                "current_status": color,
                "manual_color": color,
                "last_updated": now_utc
            }}
        )
        msg_mode = f"{color} in MANUAL mode"

    return jsonify({
        "success": True,
        "message": f"Signal {junction_id} set to {msg_mode}"
    }), 200
# ================= SET ACTIVE LIGHT =================
@app.route('/api/admin/set_active_light', methods=['POST'])
def set_active_light():
    data         = request.json
    junction_id  = data.get('junction_id')
    active_light = int(data.get('active_light'))

    signals_collection.update_one(
        {"junction_id": junction_id},
        {"$set": {
            "active_light": active_light,
            "mode":         "MANUAL",
            "last_updated": datetime.datetime.utcnow()
        }}
    )
    return jsonify({"success": True, "message": f"Active light set to {active_light}"}), 200

@app.route('/api/admin/signals', methods=['GET'])
def get_all_signals():
    try:
        signals = list(signals_collection.find({}, {"_id": 0}).sort("junction_id", 1))
        for s in signals:
            s['battery_level'] = s.get('battery_level', 100)
            lu = s.get('last_updated', datetime.datetime.utcnow())
            if isinstance(lu, datetime.datetime):
                s['last_updated'] = lu.isoformat()
            else:
                s['last_updated'] = str(lu)
        return jsonify(signals), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
    # ================= ESP32 JUNCTION STATUS POLLING =================
@app.route('/api/junction/status', methods=['GET'])
def get_junction_status():
    esp32_id = request.args.get('esp32_id', '')

    junction = signals_collection.find_one({"esp32_id": esp32_id}, {"_id": 0})

    if not junction:
        return jsonify({"success": False, "message": "Junction not found"}), 404

    active_light   = junction.get('active_light', 1)
    current_status = junction.get('current_status', 'RED')
    mode           = junction.get('mode', 'AUTO')
    manual_color   = junction.get('manual_color', None)

    lights = {}
    for i in range(1, 5):
        if i == active_light:
            if mode == "MANUAL" and manual_color:
                lights[f"light_{i}"] = manual_color
            else:
                lights[f"light_{i}"] = current_status
        else:
            lights[f"light_{i}"] = "RED"

    return jsonify({
        "junction_id":  junction.get('junction_id'),
        "mode":         mode,
        "active_light": active_light,
        **lights
    }), 200
@app.route('/api/admin/requests', methods=['GET'])
def get_active_requests():
    try:
        time_limit = datetime.datetime.utcnow() - datetime.timedelta(days=15)

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
                "username": user['username'], 
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

# ================= DAEMON THREAD FOR TRAFFIC LIGHTS =================
def traffic_light_loop():
    while True:
        try:
            now       = datetime.datetime.utcnow()
            junctions = signals_collection.find({"mode": "AUTO"})

            for junction in junctions:
                current_status   = junction.get('current_status', 'RED')
                last_updated     = junction.get('last_updated', now)
                active_light     = junction.get('active_light', 1)

                if not isinstance(last_updated, datetime.datetime):
                    last_updated = now

                elapsed          = (now - last_updated).total_seconds()
                new_status       = current_status
                new_active_light = active_light

                # GREEN 7s → YELLOW 2s → RED 1s → next lane
                if current_status == "GREEN" and elapsed >= 7:
                    new_status = "YELLOW"

                elif current_status == "YELLOW" and elapsed >= 2:
                    new_status       = "RED"
                    new_active_light = (active_light % 4) + 1  # 1→2→3→4→1

                elif current_status == "RED" and elapsed >= 1:
                    new_status = "GREEN"

                if new_status != current_status or new_active_light != active_light:
                    signals_collection.update_one(
                        {"_id": junction["_id"]},
                        {"$set": {
                            "current_status": new_status,
                            "active_light":   new_active_light,
                            "last_updated":   now
                        }}
                    )
                    print(f"🚦 {junction['junction_name']}: Light {new_active_light} → {new_status}")

        except Exception as e:
            print(f"Traffic Loop Error: {e}")

        time.sleep(1)  # Every 1 second for smooth transitions

# ================= START BACKGROUND DAEMON =================
# We start the loop here unconditionally so that it works when Render runs the app via Gunicorn (WSGI)
# instead of python auth_server.py
threading.Thread(target=traffic_light_loop, daemon=True).start()

# ================= RUN SERVER =================
if __name__ == '__main__':
    # Render assigns a dynamic port via the PORT environment variable
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)