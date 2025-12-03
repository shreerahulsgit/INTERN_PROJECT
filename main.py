from fastapi import FastAPI, UploadFile, File, Request
from fastapi.middleware.cors import CORSMiddleware
import cv2
from ultralytics import YOLO
from deep_sort_realtime.deepsort_tracker import DeepSort
import threading
import os
import json
from pathlib import Path
from threading import Lock

# --------------------------
# GLOBAL VARIABLES
# --------------------------
current_count = 0
processing = False
VIDEO_PATH = None  # dynamic now
_state_lock = Lock()

# --------------------------
# SETTINGS
# --------------------------
MIN_BOX_AREA = 900
MIN_ASPECT_RATIO = 0.3
MAX_ASPECT_RATIO = 3.5
TRACK_CONSECUTIVE_FRAMES_TO_COUNT = 12
TRACK_MAX_AGE = 18
MODEL_PATH = r"models/yolov8n.pt"

# Try a few fallbacks if MODEL_PATH doesn't exist
if not Path(MODEL_PATH).exists():
    if Path('yolov8n.pt').exists():
        MODEL_PATH = 'yolov8n.pt'
    elif Path('../yolov8n.pt').exists():
        MODEL_PATH = '../yolov8n.pt'
    else:
        print(f"WARNING: Model not found at {MODEL_PATH}. Ensure yolov8n.pt exists.")

# --------------------------
# FastAPI setup
# --------------------------
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --------------------------
# Load YOLO model
# --------------------------
print("Loading YOLO model...")
try:
    yolo = YOLO(MODEL_PATH)
except Exception as e:
    print("Failed to load YOLO model:", e)
    yolo = None

# --------------------------
# Init DeepSORT
# --------------------------
tracker = DeepSort(
    max_age=TRACK_MAX_AGE,
    n_init=5,
    nn_budget=100,
    max_iou_distance=0.7
)

# --------------------------
# Helper function to convert YOLO predictions
# --------------------------
def convert_yolo_predictions(results):
    detections = []
    for r in results:
        for box in r.boxes:
            cls = int(box.cls[0])
            conf = float(box.conf[0])
            if cls != 0:  # only detect "person"
                continue

            x1, y1, x2, y2 = box.xyxy[0].tolist()
            area = max(0, x2 - x1) * max(0, y2 - y1)
            if area < MIN_BOX_AREA:
                continue

            wh = max(1, x2 - x1)
            aspect = (y2 - y1) / wh
            if aspect < MIN_ASPECT_RATIO or aspect > MAX_ASPECT_RATIO:
                continue

            detections.append(([x1, y1, x2, y2], conf, "person"))

    return sorted(detections, key=lambda x: x[0][0])

# --------------------------
# Video processing thread
# --------------------------
def process_video():
    global current_count, processing, VIDEO_PATH

    cap = cv2.VideoCapture(VIDEO_PATH)
    if not cap.isOpened():
        print("❌ Video not found")
        with _state_lock:
            processing = False
        return

    confirmed_ids = set()
    consecutive_seen = {}
    last_seen_frame_idx = {}
    frame_idx = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame_idx += 1
        if yolo is None:
            print("YOLO model not loaded, aborting processing")
            break

        try:
            yolo_results = yolo(frame, conf=0.6)
        except Exception as e:
            print("YOLO inference error:", e)
            continue

        detections = convert_yolo_predictions(yolo_results)
        tracks = tracker.update_tracks(detections, frame=frame)

        seen_this_frame = set()
        for t in tracks:
            if not t.is_confirmed():
                continue

            tid = t.track_id
            seen_this_frame.add(tid)

            if last_seen_frame_idx.get(tid, 0) == frame_idx - 1:
                consecutive_seen[tid] = consecutive_seen.get(tid, 0) + 1
            else:
                consecutive_seen[tid] = 1

            last_seen_frame_idx[tid] = frame_idx

            if consecutive_seen[tid] >= TRACK_CONSECUTIVE_FRAMES_TO_COUNT:
                confirmed_ids.add(tid)

        # Remove old tracks
        for tid in list(consecutive_seen.keys()):
            if tid not in seen_this_frame:
                last_idx = last_seen_frame_idx.get(tid, 0)
                if (frame_idx - last_idx) > TRACK_MAX_AGE:
                    consecutive_seen.pop(tid, None)
                    last_seen_frame_idx.pop(tid, None)
                else:
                    consecutive_seen[tid] = 0

        with _state_lock:
            current_count = len(confirmed_ids)

    cap.release()
    with _state_lock:
        processing = False
    print("✔ Final Student Count:", current_count)

# --------------------------
# API ENDPOINTS
# --------------------------

# 1️⃣ Process video via JSON URL/path
@app.post("/process_video_url")
async def start_processing_json(request: Request):
    global VIDEO_PATH, processing
    if processing:
        return {"status": "already_running"}

    data = await request.json()
    VIDEO_PATH = data.get("url")
    if not VIDEO_PATH:
        return {"status": "error", "message": "No URL/path provided"}

    with _state_lock:
        processing = True
    threading.Thread(target=process_video, daemon=True).start()
    return {"status": "processing_started"}

# 2️⃣ Process video via uploaded file
@app.post("/process_video_file")
async def process_video_file(file: UploadFile = File(...)):
    global VIDEO_PATH, processing
    if processing:
        return {"status": "already_running"}

    tmp_path = f"temp_{file.filename}"
    with open(tmp_path, "wb") as f:
        f.write(await file.read())

    VIDEO_PATH = tmp_path
    with _state_lock:
        processing = True
    threading.Thread(target=process_video, daemon=True).start()
    return {"status": "processing_started"}

# 3️⃣ Get current count
@app.get("/count")
def get_current_count():
    with _state_lock:
        return {"count": current_count, "processing": processing}


if __name__ == '__main__':
    # Allow running the FastAPI app directly with python main.py
    try:
        import uvicorn
        print("Starting uvicorn HTTP server on 0.0.0.0:8000")
        uvicorn.run("main:app", host="0.0.0.0", port=8000)
    except Exception as e:
        print("uvicorn is not available or failed to start:", e)
        print("You can start the server with: uvicorn main:app --host 0.0.0.0 --port 8000")
