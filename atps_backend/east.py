import requests
import time

SERVER = "http://127.0.0.1:5000/api"

steps = 15
for i in range(steps):
    amb_lat = 9.699518
    amb_lon = 76.811300 - (i * 0.000050)  # moves westward

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