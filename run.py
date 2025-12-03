# main.py
from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
import sqlite3
import random

from datetime import datetime, timedelta
from typing import Optional, Dict, Any

# -----------------------
# CONFIG
# -----------------------
DB_PATH = "campus_connect.db"
JWT_SECRET = "replace-this-with-a-secure-random-secret"  # change before production
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 hours

# -----------------------
# FastAPI init
# -----------------------
app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # change in production
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------
# DB (sqlite)
# -----------------------
conn = sqlite3.connect(DB_PATH, check_same_thread=False)
cur = conn.cursor()

cur.execute(
    """
CREATE TABLE IF NOT EXISTS staff (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE,
    name TEXT,
    department TEXT,
    otp INTEGER
)
"""
)

cur.execute(
    """
CREATE TABLE IF NOT EXISTS student (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE,
    name TEXT,
    department TEXT,
    year TEXT,
    otp INTEGER
)
"""
)
conn.commit()

# -----------------------
# Schemas
# -----------------------
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

# -----------------------
# Helpers
# -----------------------
def generate_otp() -> int:
    return random.randint(100000, 999999)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    now = datetime.utcnow()
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire, "iat": now})
    token = jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGORITHM)
    return token

def decode_access_token(token: str) -> Dict[str, Any]:
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload
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

# -----------------------
# Health
# -----------------------
@app.get("/health")
def health():
    return {"ok": True, "db": "connected"}

# -----------------------
# STAFF OTP / VERIFY / REGISTER
# -----------------------
@app.post("/api/staff/send_otp")
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
    print(f"[STAFF OTP] {email} -> {otp}")
    return {"detail": "OTP sent", "otp": otp}

@app.post("/api/staff/verify_otp")
def verify_staff_otp(data: OTPVerifySchema):
    cur.execute("SELECT otp FROM staff WHERE email=?", (data.email.lower().strip(),))
    row = cur.fetchone()
    if not row or row[0] != data.otp:
        raise HTTPException(status_code=400, detail="Invalid OTP")
    cur.execute("UPDATE staff SET otp=NULL WHERE email=?", (data.email.lower().strip(),))
    conn.commit()
    return {"detail": "OTP verified"}

@app.post("/api/staff/register")
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

# -----------------------
# STUDENT OTP / VERIFY / REGISTER
# -----------------------
@app.post("/api/student/send_otp")
def send_student_otp(data: EmailSchema):
    email = data.email.lower().strip()
    cur.execute("SELECT name FROM student WHERE email=?", (email,))
    existing = cur.fetchone()
    if existing and existing[0] is not None:
        raise HTTPException(status_code=400, detail="Email already registered")
    local = email.split("@")[0]
    if not email.endswith("@citchennai.net") or "." not in local:
        raise HTTPException(status_code=400, detail="Invalid student email (use name.deptYear@citchennai.net)")
    otp = generate_otp()
    cur.execute("SELECT id FROM student WHERE email=?", (email,))
    row = cur.fetchone()
    if row:
        cur.execute("UPDATE student SET otp=? WHERE email=?", (otp, email))
    else:
        cur.execute("INSERT INTO student (email, otp) VALUES (?, ?)", (email, otp))
    conn.commit()
    print(f"[STUDENT OTP] {email} -> {otp}")
    return {"detail": "OTP sent", "otp": otp}

@app.post("/api/student/verify_otp")
def verify_student_otp(data: OTPVerifySchema):
    cur.execute("SELECT otp FROM student WHERE email=?", (data.email.lower().strip(),))
    row = cur.fetchone()
    if not row or row[0] != data.otp:
        raise HTTPException(status_code=400, detail="Invalid OTP")
    cur.execute("UPDATE student SET otp=NULL WHERE email=?", (data.email.lower().strip(),))
    conn.commit()
    return {"detail": "OTP verified"}

@app.post("/api/student/register")
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

# -----------------------
# Login -> issue JWT for registered users

# -----------------------
@app.post("/api/staff/resend_otp")
def resend_staff_otp(data: EmailSchema):
    email = data.email.lower().strip()
    cur.execute("SELECT id FROM staff WHERE email=?", (email,))
    row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=400, detail="Email not found; request OTP first")
    
    otp = generate_otp()
    cur.execute("UPDATE staff SET otp=? WHERE email=?", (otp, email))
    conn.commit()
    print(f"[STAFF RESEND OTP] {email} -> {otp}")
    return {"detail": "OTP resent", "otp": otp}
@app.post("/api/student/resend_otp")
def resend_student_otp(data: EmailSchema):
    email = data.email.lower().strip()
    cur.execute("SELECT id FROM student WHERE email=?", (email,))
    row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=400, detail="Email not found; request OTP first")
    
    otp = generate_otp()
    cur.execute("UPDATE student SET otp=? WHERE email=?", (otp, email))
    conn.commit()
    print(f"[STUDENT RESEND OTP] {email} -> {otp}")
    return {"detail": "OTP resent", "otp": otp}
@app.post("/api/auth/login", response_model=TokenResponse)
def login(req: LoginRequest):
    email = req.email.lower().strip()
    user = find_user_by_email(email)
    if not user:
        raise HTTPException(status_code=400, detail="Email not registered")
    rec = user["record"]
    if not rec.get("name"):
        raise HTTPException(status_code=400, detail="User not registered (complete registration first)")
    role = user["role"]
    payload = {
        "sub": email,
        "role": role,
        "name": rec.get("name"),
    }
    token = create_access_token(payload, expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    expires_at = int((datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)).timestamp())
    return {"access_token": token, "token_type": "bearer", "expires_at": expires_at}

# -----------------------
# Protected route example
# -----------------------
def _extract_bearer(request: Request) -> Optional[str]:
    auth = request.headers.get("authorization")
    if not auth:
        return None
    parts = auth.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return None
    return parts[1]

@app.get("/api/me")
def me(request: Request):
    token = _extract_bearer(request)
    if not token:
        raise HTTPException(status_code=401, detail="Missing authorization header")
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
    email = payload.get("sub")
    user = find_user_by_email(email)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {"user": user}

# -----------------------
# Simple admin listing endpoints
# -----------------------
@app.get("/api/staff")
def list_staff():
    cur.execute("SELECT id, email, name, department FROM staff")
    rows = cur.fetchall()
    return {"staff": [{"id": r[0], "email": r[1], "name": r[2], "department": r[3]} for r in rows]}

@app.get("/api/student")
def list_students():
    cur.execute("SELECT id, email, name, department, year FROM student")
    rows = cur.fetchall()
    return {"students": [{"id": r[0], "email": r[1], "name": r[2], "department": r[3], "year": r[4]} for r in rows]}

# -----------------------
# Run notes
# -----------------------
# Start server with custom port NUM (replace NUM with your desired port):
#   uvicorn main:app --reload --host 0.0.0.0 --port NUM
# Example:
#   uvicorn main:app --reload --host 0.0.0.0 --port 5000
# In emulator use base URL http://10.0.2.2:5000
# For production:
# - Replace JWT_SECRET with a secure value (from env)
# - Use HTTPS
# - Remove OTP echoes and integrate real email sending
# - Tighten CORS origins
