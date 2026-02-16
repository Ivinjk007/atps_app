from flask import Flask, request, jsonify
from pymongo import MongoClient
from flask_cors import CORS
import datetime

# ================= APP SETUP =================
app = Flask(__name__)
CORS(app)

# ================= DATABASE CONNECTION =================
MONGO_URI = "mongodb+srv://admin:admin123@cluster0.oiagpxv.mongodb.net/?appName=Cluster0"

try:
    client = MongoClient(MONGO_URI)
    db = client.get_database("atps_db")

    users_collection = db.users
    authorized_admins = db.authorized_admins

    print("✅ Connected to MongoDB Cloud successfully!")
except Exception as e:
    print(f"❌ Connection Error: {e}")

# ================= HOME ROUTE =================
@app.route('/')
def home():
    return "ATPS Auth Server is Running!"

# ================= SIGNUP =================
@app.route('/api/signup', methods=['POST'])
def signup():
    print("🔥 SIGNUP API CALLED")

    data = request.json
    username = data.get('username')
    role = data.get('role', 'DRIVER').upper()
    unit_id = data.get('unit_id', '').upper()

    print("📩 Signup Data:", data)

    # 1️⃣ Check username already exists
    if users_collection.find_one({"username": username}):
        return jsonify({
            "success": False,
            "message": "Username already taken"
        }), 400

    # 2️⃣ Validate role & unit ID
    if role == "ADMIN":

        # format check
        if not unit_id.startswith("CYBER-"):
            return jsonify({
                "success": False,
                "message": "Admin ID must start with CYBER-"
            }), 400

        # authorization check
        authorized = authorized_admins.find_one({
            "unit_id": unit_id,
            "active": True
        })

        if not authorized:
            return jsonify({
                "success": False,
                "message": "Unauthorized Admin ID"
            }), 403

    elif role == "DRIVER":

        if not unit_id.startswith("AMB-"):
            return jsonify({
                "success": False,
                "message": "Ambulance ID must start with AMB-"
            }), 400

    # 3️⃣ Create user document
    new_user = {
        "name": data.get('name'),
        "username": username,
        "password": data.get('password'),  # ⚠️ hash in production
        "unit_id": unit_id,
        "role": role,
        "created_at": datetime.datetime.utcnow()
    }

    users_collection.insert_one(new_user)

    print(f"🆕 New {role} Created: {username} ({unit_id})")

    return jsonify({
        "success": True,
        "message": f"{role} Account created successfully!"
    }), 201

# ================= LOGIN =================
@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    username = data.get('username')
    password = data.get('password')
    requested_role = data.get('role')

    print("🔐 Login attempt:", username)

    # Find user
    user = users_collection.find_one({
        "username": username,
        "password": password
    })

    if user:

        # Prevent driver accessing admin panel
        if requested_role == "ADMIN" and user.get("role") != "ADMIN":
            print(f"⛔ Security Alert: {username} tried admin access")
            return jsonify({
                "success": False,
                "message": "Access Denied: Not an Administrator"
            }), 403

        print(f"🔓 Login Success: {username} as {user.get('role')}")

        return jsonify({
            "success": True,
            "message": "Login Successful",
            "user": {
                "name": user.get("name"),
                "unit_id": user.get("unit_id"),
                "role": user.get("role")
            }
        }), 200

    else:
        print(f"❌ Login Failed: {username}")
        return jsonify({
            "success": False,
            "message": "Invalid Username or Password"
        }), 401

# ================= RUN SERVER =================
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
