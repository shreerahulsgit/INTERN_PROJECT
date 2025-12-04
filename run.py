# main.py
from fastapi import FastAPI, HTTPException, Request, APIRouter
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from typing import Optional, Dict, Any
from datetime import datetime, timedelta
import sqlite3
import random


# -----------------------
# CONFIG
# -----------------------
DB_PATH = "campus_connect.db"
JWT_SECRET = "replace-this-with-a-secure-random-secret"  # replace in production
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 hours

# -----------------------
# FastAPI init
# -----------------------
app = FastAPI(title="CampusConnect Backend")

# -----------------------
# Enable CORS
# -----------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------
# Database (SQLite)
# -----------------------
conn = sqlite3.connect(DB_PATH, check_same_thread=False)
cur = conn.cursor()

# Staff table
cur.execute("""
CREATE TABLE IF NOT EXISTS staff (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE,
    name TEXT,
    department TEXT,
    otp INTEGER
)
""")

# Student table
cur.execute("""
CREATE TABLE IF NOT EXISTS student (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE,
    name TEXT,
    department TEXT,
    year TEXT,
    otp INTEGER
)
""")

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

def _extract_bearer(request: Request) -> Optional[str]:
    auth = request.headers.get("authorization")
    if not auth:
        return None
    parts = auth.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return None
    return parts[1]

# -----------------------
# Routers
# -----------------------
staff_router = APIRouter(prefix="/api/staff", tags=["Staff"])
student_router = APIRouter(prefix="/api/student", tags=["Student"])
auth_router = APIRouter(prefix="/api/auth", tags=["Auth"])

# -----------------------
# Staff endpoints
# -----------------------
@staff_router.post("/send_otp")
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

@staff_router.post("/verify_otp")
def verify_staff_otp(data: OTPVerifySchema):
    cur.execute("SELECT otp FROM staff WHERE email=?", (data.email.lower().strip(),))
    row = cur.fetchone()
    if not row or row[0] != data.otp:
        raise HTTPException(status_code=400, detail="Invalid OTP")
    cur.execute("UPDATE staff SET otp=NULL WHERE email=?", (data.email.lower().strip(),))
    conn.commit()
    return {"detail": "OTP verified"}

# -----------------------
# Student endpoints
# -----------------------
@student_router.post("/send_otp")
def send_student_otp(data: EmailSchema):
    email = data.email.lower().strip()
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
    print(f"[STUDENT OTP] {email} -> {otp}")
    return {"detail": "OTP sent", "otp": otp}

@student_router.post("/verify_otp")
def verify_student_otp(data: OTPVerifySchema):
    cur.execute("SELECT otp FROM student WHERE email=?", (data.email.lower().strip(),))
    row = cur.fetchone()
    if not row or row[0] != data.otp:
        raise HTTPException(status_code=400, detail="Invalid OTP")
    cur.execute("UPDATE student SET otp=NULL WHERE email=?", (data.email.lower().strip(),))
    conn.commit()
    return {"detail": "OTP verified"}

# -----------------------
# Auth endpoints (login)
# -----------------------
@auth_router.post("/login", response_model=TokenResponse)
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
    token = create_access_token(payload)
    expires_at = int((datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)).timestamp())
    return {"access_token": token, "token_type": "bearer", "expires_at": expires_at}

# -----------------------
# Include Routers
# -----------------------
app.include_router(staff_router)
app.include_router(student_router)
app.include_router(auth_router)

# -----------------------
# Health check
# -----------------------
@app.get("/health")
def health():
    return {"ok": True, "db": "connected"}
