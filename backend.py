# app.py (full corrected)

from fastapi import FastAPI, HTTPException, Request, UploadFile, File, APIRouter
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from typing import Optional, Dict, Any
from datetime import datetime, timedelta
import sqlite3
import random
import threading
from threading import Lock
from pathlib import Path
import cv2
from ultralytics import YOLO
from deep_sort_realtime.deepsort_tracker import DeepSort


# --------------------------
# GLOBAL VARIABLES
# --------------------------
current_count = 0
processing = False
VIDEO_PATH = None
_state_lock = Lock()

MIN_BOX_AREA = 900
MIN_ASPECT_RATIO = 0.3
MAX_ASPECT_RATIO = 3.5
TRACK_CONSECUTIVE_FRAMES_TO_COUNT = 12
TRACK_MAX_AGE = 18
MODEL_PATH = r"models/yolov8n.pt"

# --------------------------
# FastAPI App
# --------------------------
app = FastAPI(title="CampusConnect + YOLO Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --------------------------
# YOLO + DeepSORT Init
# --------------------------
if not Path(MODEL_PATH).exists():
    if Path('yolov8n.pt').exists():
        MODEL_PATH = 'yolov8n.pt'
    elif Path('../yolov8n.pt').exists():
        MODEL_PATH = '../yolov8n.pt'
    else:
        print(f"WARNING: Model not found at {MODEL_PATH}.")

try:
    yolo = YOLO(MODEL_PATH)
except Exception as e:
    print("Failed to load YOLO model:", e)
    yolo = None

tracker = DeepSort(max_age=TRACK_MAX_AGE, n_init=5, nn_budget=100, max_iou_distance=0.7)

# --------------------------
# DATABASE (CampusConnect)
# --------------------------
DB_PATH = "campus_connect.db"
JWT_SECRET = "replace-this-with-a-secure-random-secret"
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24

conn = sqlite3.connect(DB_PATH, check_same_thread=False)
cur = conn.cursor()

cur.execute("""CREATE TABLE IF NOT EXISTS staff (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE,
    name TEXT,
    department TEXT,
    otp INTEGER
)""")

cur.execute("""CREATE TABLE IF NOT EXISTS student (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE,
    name TEXT,
    department TEXT,
    year TEXT,
    otp INTEGER
)""")
conn.commit()

# --------------------------
# SCHEMAS
# --------------------------
class EmailSchema(BaseModel):
    email: EmailStr

class OTPVerifySchema(BaseModel):
    email: EmailStr
    otp: int

class StaffRegisterSchema(BaseModel):
    email: EmailStr
    name: str
    department: str

class StudentRegisterSchema(BaseModel):
    email: EmailStr
    name: str
    department: str
    year: str

class LoginRequest(BaseModel):
    email: EmailStr

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_at: int

# --------------------------
# HELPERS
# --------------------------
def generate_otp() -> int:
    return random.randint(100000, 999999)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    now = datetime.utcnow()
    expire = now + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire, "iat": now})
    return jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGORITHM)

def decode_access_token(token: str) -> Dict[str, Any]:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

def find_user_by_email(email: str) -> Optional[Dict[str, Any]]:
    cur.execute("SELECT id, email, name, department FROM staff WHERE email=?", (email,))
    r = cur.fetchone()
    if r:
        return {"role": "staff", "record": {"id": r[0], "email": r[1], "name": r[2], "department": r[3]}}
    cur.execute("SELECT id, email, name, department, year FROM student WHERE email=?", (email,))
    r = cur.fetchone()
    if r:
        return {"role": "student", "record": {"id": r[0], "email": r[1], "name": r[2], "department": r[3], "year": r[4]}}
    return None

def _extract_bearer(request: Request) -> Optional[str]:
    auth = request.headers.get("authorization")
    if not auth:
        return None
    parts = auth.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return None
    return parts[1]

# --------------------------
# ROUTERS
# --------------------------
router = APIRouter(prefix="/api")

# --- Staff / Student routes ---
@router.post("/staff/send_otp")
def send_staff_otp(data: EmailSchema):
    email = data.email.lower().strip()
    if not email.endswith("@citchennai.net"):
        raise HTTPException(status_code=400, detail="Invalid college email")
    otp = generate_otp()
    cur.execute("SELECT id FROM staff WHERE email=?", (email,))
    row = cur.fetchone()
    if row:
        cur.execute("UPDATE staff SET otp=? WHERE email=?", (otp, email))
    else:
        cur.execute("INSERT INTO staff (email, otp) VALUES (?,?)", (email, otp))
    conn.commit()
    print(f"[STAFF OTP] {email} -> {otp}")  # <-- prints OTP
    return {"detail": "OTP sent", "otp": otp}

@router.post("/staff/verify_otp")
def verify_staff_otp(data: OTPVerifySchema):
    cur.execute("SELECT otp FROM staff WHERE email=?", (data.email.lower().strip(),))
    row = cur.fetchone()
    if not row or row[0] != data.otp:
        raise HTTPException(status_code=400, detail="Invalid OTP")
    cur.execute("UPDATE staff SET otp=NULL WHERE email=?", (data.email.lower().strip(),))
    conn.commit()
    return {"detail": "OTP verified"}

@router.post("/staff/register")
def register_staff(data: StaffRegisterSchema):
    email = data.email.lower().strip()
    cur.execute("SELECT otp, name FROM staff WHERE email=?", (email,))
    row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=400, detail="Email not found; request OTP first")
    if row[0] is not None:
        raise HTTPException(status_code=400, detail="Email not verified; verify OTP first")
    if row[1] is not None:
        raise HTTPException(status_code=400, detail="Email already registered")
    cur.execute("UPDATE staff SET name=?, department=? WHERE email=?", (data.name, data.department, email))
    conn.commit()
    return {"detail": "Staff registered"}

# Student OTP routes
@router.post("/student/send_otp")
def send_student_otp(data: EmailSchema):
    email = data.email.lower().strip()
    cur.execute("SELECT name FROM student WHERE email=?", (email,))
    existing = cur.fetchone()
    if existing and existing[0] is not None:
        raise HTTPException(status_code=400, detail="Email already registered")
    local = email.split("@")[0]
    if not email.endswith("@citchennai.net") or "." not in local:
        raise HTTPException(status_code=400, detail="Invalid student email")
    otp = generate_otp()
    cur.execute("SELECT id FROM student WHERE email=?", (email,))
    row = cur.fetchone()
    if row:
        cur.execute("UPDATE student SET otp=? WHERE email=?", (otp, email))
    else:
        cur.execute("INSERT INTO student (email, otp) VALUES (?, ?)", (email, otp))
    conn.commit()
    print(f"[STUDENT OTP] {email} -> {otp}")  # <-- prints OTP
    return {"detail": "OTP sent", "otp": otp}

@router.post("/student/verify_otp")
def verify_student_otp(data: OTPVerifySchema):
    cur.execute("SELECT otp FROM student WHERE email=?", (data.email.lower().strip(),))
    row = cur.fetchone()
    if not row or row[0] != data.otp:
        raise HTTPException(status_code=400, detail="Invalid OTP")
    cur.execute("UPDATE student SET otp=NULL WHERE email=?", (data.email.lower().strip(),))
    conn.commit()
    return {"detail": "OTP verified"}

@router.post("/student/register")
def register_student(data: StudentRegisterSchema):
    email = data.email.lower().strip()
    cur.execute("SELECT name, otp FROM student WHERE email=?", (email,))
    row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=400, detail="Email not found; request OTP first")
    if row[0] is not None:
        raise HTTPException(status_code=400, detail="Email already registered")
    if row[1] is not None:
        raise HTTPException(status_code=400, detail="Email not verified; verify OTP first")
    cur.execute("UPDATE student SET name=?, department=?, year=? WHERE email=?", (data.name, data.department, data.year, email))
    conn.commit()
    return {"detail": "Student registered"}

# Login
@router.post("/login", response_model=TokenResponse)
def login(req: LoginRequest):
    email = req.email.lower().strip()
    user = find_user_by_email(email)
    if not user:
        raise HTTPException(status_code=400, detail="Email not registered")
    rec = user["record"]
    if not rec.get("name"):
        raise HTTPException(status_code=400, detail="User not registered")
    role = user["role"]
    payload = {"sub": email, "role": role, "name": rec.get("name")}
    token = create_access_token(payload, expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    expires_at = int((datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)).timestamp())
    return {"access_token": token, "token_type": "bearer", "expires_at": expires_at}

# Protected route
@router.get("/me")
def me(request: Request):
    token = _extract_bearer(request)
    if not token:
        raise HTTPException(status_code=401, detail="Missing authorization header")
    payload = decode_access_token(token)
    email = payload.get("sub")
    user = find_user_by_email(email)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {"user": user}

# Include router
app.include_router(router)

# --------------------------
# Video Processing Endpoints
# --------------------------
def convert_yolo_predictions(results):
    detections = []
    for r in results:
        for box in r.boxes:
            cls = int(box.cls[0])
            conf = float(box.conf[0])
            if cls != 0:  # only person
                continue
            x1, y1, x2, y2 = box.xyxy[0].tolist()
            area = max(0, x2-x1) * max(0, y2-y1)
            if area < MIN_BOX_AREA:
                continue
            wh = max(1, x2-x1)
            aspect = (y2-y1)/wh
            if aspect < MIN_ASPECT_RATIO or aspect > MAX_ASPECT_RATIO:
                continue
            detections.append(([x1, y1, x2, y2], conf, "person"))
    return sorted(detections, key=lambda x: x[0][0])

def process_video():
    global current_count, processing, VIDEO_PATH
    cap = cv2.VideoCapture(VIDEO_PATH)
    if not cap.isOpened():
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
            break
        try:
            yolo_results = yolo(frame, conf=0.6)
        except:
            continue
        detections = convert_yolo_predictions(yolo_results)
        tracks = tracker.update_tracks(detections, frame=frame)
        seen_this_frame = set()
        for t in tracks:
            if not t.is_confirmed(): continue
            tid = t.track_id
            seen_this_frame.add(tid)
            if last_seen_frame_idx.get(tid, 0) == frame_idx-1:
                consecutive_seen[tid] = consecutive_seen.get(tid,0)+1
            else:
                consecutive_seen[tid] = 1
            last_seen_frame_idx[tid] = frame_idx
            if consecutive_seen[tid]>=TRACK_CONSECUTIVE_FRAMES_TO_COUNT:
                confirmed_ids.add(tid)
        for tid in list(consecutive_seen.keys()):
            if tid not in seen_this_frame:
                last_idx = last_seen_frame_idx.get(tid,0)
                if (frame_idx - last_idx) > TRACK_MAX_AGE:
                    consecutive_seen.pop(tid,None)
                    last_seen_frame_idx.pop(tid,None)
                else:
                    consecutive_seen[tid]=0
        with _state_lock:
            current_count = len(confirmed_ids)
    cap.release()
    with _state_lock:
        processing = False

@app.post("/process_video_url")
async def start_processing_json(request: Request):
    global VIDEO_PATH, processing
    if processing: return {"status":"already_running"}
    data = await request.json()
    VIDEO_PATH = data.get("url")
    if not VIDEO_PATH: return {"status":"error","message":"No URL/path provided"}
    with _state_lock:
        processing=True
    threading.Thread(target=process_video, daemon=True).start()
    return {"status":"processing_started"}

@app.get("/count")
def get_current_count():
    with _state_lock:
        return {"count": current_count, "processing": processing}

@app.get("/health")
def health():
    return {"ok": True, "db": "connected"}