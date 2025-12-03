from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import List
import random
import copy

# ------------------------
# Models
# ------------------------
class SessionInput(BaseModel):
    subject: str
    teacher: str
    group: str
    hours: int = 1

class DepartmentModel(BaseModel):
    name: str
    groups: List[str]
    sessions: List[SessionInput]

class TimetableRequest(BaseModel):
    departments: List[DepartmentModel]
    timeslots: List[str]

# ------------------------
# FastAPI Setup
# ------------------------
app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

PERIODS = ["P1","P2","P3","break","P4","P5","lunch","P6","P7","P8"]
DAYS = ["Mon","Tue","Wed","Thu","Fri"]

# ------------------------
# CSP Preprocessing
# ------------------------
def apply_csp(req: TimetableRequest):
    timetable = {dept.name: {day: {p: None for p in PERIODS} for day in DAYS} for dept in req.departments}
    staff_schedule = {day: {p: set() for p in PERIODS} for day in DAYS}

    for day in DAYS:
        for period in PERIODS:
            if period in ["break", "lunch"]:
                for dept in req.departments:
                    timetable[dept.name][day][period] = {"subject": period.capitalize(), "teacher": None, "group": None, "time": f"{day}-{period}"}
                continue

            for dept in req.departments:
                assigned = False
                random.shuffle(dept.sessions)
                for s in dept.sessions:
                    if s.teacher not in staff_schedule[day][period]:
                        timetable[dept.name][day][period] = {"subject": s.subject, "teacher": s.teacher, "group": s.group, "time": f"{day}-{period}"}
                        staff_schedule[day][period].add(s.teacher)
                        assigned = True
                        break
                if not assigned:
                    timetable[dept.name][day][period] = {"subject": "Free", "teacher": None, "group": None, "time": f"{day}-{period}"}
    return timetable

# ------------------------
# Genetic Algorithm Optimization
# ------------------------
def ga_optimize(timetable):
    def fitness(table):
        score = 0
        for day in DAYS:
            for period in PERIODS:
                teachers_seen = set()
                for dept, days in table.items():
                    teacher = days[day][period]['teacher']
                    if teacher and teacher in teachers_seen:
                        score -= 1  # teacher clash penalty
                    teachers_seen.add(teacher)
        return score

    # Generate initial population
    population = [copy.deepcopy(timetable) for _ in range(10)]

    for generation in range(50):  # 50 generations
        population.sort(key=lambda t: fitness(t), reverse=True)
        # crossover top 2
        parent1, parent2 = population[0], population[1]
        child = copy.deepcopy(parent1)
        # swap random day
        swap_day = random.choice(DAYS)
        for dept in timetable.keys():
            child[dept][swap_day], parent2[dept][swap_day] = parent2[dept][swap_day], child[dept][swap_day]
        population[-1] = child
        # mutation
        mut_day = random.choice(DAYS)
        mut_period = random.choice([p for p in PERIODS if p not in ["break","lunch"]])
        for dept, days in child.items():
            day_schedule = days[mut_day]
            # swap two sessions randomly
            p1, p2 = random.sample([p for p in PERIODS if p not in ["break","lunch"]], 2)
            day_schedule[p1], day_schedule[p2] = day_schedule[p2], day_schedule[p1]

    # Return best
    population.sort(key=lambda t: fitness(t), reverse=True)
    return population[0]

# ------------------------
# API Endpoint
# ------------------------
@app.post("/generate_timetable")
def generate_timetable(req: TimetableRequest):
    csp_timetable = apply_csp(req)
    optimized = ga_optimize(csp_timetable)
    return JSONResponse(optimized)
