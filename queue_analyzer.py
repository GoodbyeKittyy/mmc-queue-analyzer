from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import math
import numpy as np
from scipy import special
import uvicorn

app = FastAPI(title="M/M/c Queue Analyzer API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class QueueParameters(BaseModel):
    lambda_rate: float
    mu_rate: float
    c_servers: int
    simulation_time: Optional[float] = 100.0

class QueueMetrics(BaseModel):
    rho: float
    traffic_intensity: float
    p0: float
    erlang_c: float
    lq: float
    wq: float
    l: float
    w: float
    utilization: float
    stable: bool

def factorial(n: int) -> float:
    return math.factorial(n)

def calculate_p0(a: float, c: int) -> float:
    sum_term = sum(math.pow(a, k) / factorial(k) for k in range(c))
    last_term = (math.pow(a, c) / factorial(c)) * (c / (c - a))
    return 1.0 / (sum_term + last_term)

def calculate_erlang_c(a: float, c: int, rho: float) -> float:
    if rho >= 1.0:
        return 1.0
    p0 = calculate_p0(a, c)
    numerator = math.pow(a, c) / factorial(c)
    denominator = 1 - rho
    return (numerator * p0) / denominator

@app.post("/api/analyze", response_model=QueueMetrics)
async def analyze_queue(params: QueueParameters):
    lam = params.lambda_rate
    mu = params.mu_rate
    c = params.c_servers
    
    if lam <= 0 or mu <= 0 or c <= 0:
        raise HTTPException(status_code=400, detail="Parameters must be positive")
    
    rho = lam / (c * mu)
    traffic_intensity = lam / mu
    
    stable = rho < 1.0
    
    if not stable:
        return QueueMetrics(
            rho=rho,
            traffic_intensity=traffic_intensity,
            p0=0.0,
            erlang_c=1.0,
            lq=float('inf'),
            wq=float('inf'),
            l=float('inf'),
            w=float('inf'),
            utilization=rho * 100,
            stable=False
        )
    
    p0 = calculate_p0(traffic_intensity, c)
    erlang_c = calculate_erlang_c(traffic_intensity, c, rho)
    
    wq = (erlang_c / (c * mu - lam)) * 60
    lq = lam * (wq / 60)
    w = wq + (60 / mu)
    l = lam * (w / 60)
    
    return QueueMetrics(
        rho=rho,
        traffic_intensity=traffic_intensity,
        p0=p0,
        erlang_c=erlang_c,
        lq=lq,
        wq=wq,
        l=l,
        w=w,
        utilization=rho * 100,
        stable=True
    )

@app.post("/api/simulate")
async def simulate_queue(params: QueueParameters):
    lam = params.lambda_rate
    mu = params.mu_rate
    c = params.c_servers
    sim_time = params.simulation_time
    
    arrivals = []
    current_time = 0
    while current_time < sim_time:
        interarrival = np.random.exponential(1 / lam)
        current_time += interarrival
        if current_time < sim_time:
            arrivals.append(current_time)
    
    servers_busy_until = [0.0] * c
    wait_times = []
    
    for arrival_time in arrivals:
        earliest_server = min(range(c), key=lambda i: servers_busy_until[i])
        service_start = max(arrival_time, servers_busy_until[earliest_server])
        wait_time = service_start - arrival_time
        wait_times.append(wait_time)
        
        service_duration = np.random.exponential(1 / mu)
        servers_busy_until[earliest_server] = service_start + service_duration
    
    avg_wait = np.mean(wait_times) * 60 if wait_times else 0
    max_wait = np.max(wait_times) * 60 if wait_times else 0
    
    return {
        "total_arrivals": len(arrivals),
        "total_served": len(wait_times),
        "avg_wait_time_minutes": avg_wait,
        "max_wait_time_minutes": max_wait,
        "wait_times_sample": [w * 60 for w in wait_times[:10]]
    }

@app.get("/api/state-probabilities")
async def get_state_probabilities(lambda_rate: float, mu_rate: float, c_servers: int, max_states: int = 20):
    lam = lambda_rate
    mu = mu_rate
    c = c_servers
    a = lam / mu
    rho = lam / (c * mu)
    
    if rho >= 1.0:
        raise HTTPException(status_code=400, detail="System is unstable (rho >= 1)")
    
    p0 = calculate_p0(a, c)
    
    probabilities = []
    for n in range(max_states + 1):
        if n < c:
            pn = (math.pow(a, n) / factorial(n)) * p0
        else:
            pn = (math.pow(a, n) / (factorial(c) * math.pow(c, n - c))) * p0
        
        probabilities.append({
            "state": n,
            "probability": pn,
            "customers_in_queue": max(0, n - c)
        })
    
    return {
        "p0": p0,
        "states": probabilities,
        "traffic_intensity": a,
        "utilization": rho
    }

@app.get("/")
async def root():
    return {
        "message": "M/M/c Queue Analyzer API",
        "version": "1.0.0",
        "endpoints": [
            "/api/analyze",
            "/api/simulate",
            "/api/state-probabilities"
        ]
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)