import requests
import time

SERVER = "https://atps-app-1.onrender.com/api"

steps = 15
for i in range(steps):
    amb_lat = 9.699700
    amb_lon = 76.809900 + (i * 0.000050)  # moves eastward

    response = requests.post(f"{SERVER}/update_location", json={
        "username": "rohan@123",
        "unit_id": "AMB-001",
        "lat": amb_lat,
        "lon": amb_lon,
        "speed_kmh": 60,
        "priority": "Critical",
    })
    print(f"Step {i+1} | Lon: {round(amb_lon, 6)} | {response.json()}")
    time.sleep(1)