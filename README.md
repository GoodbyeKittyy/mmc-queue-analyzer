# M/M/c Queue Analyzer: Coffee Shop Edition ☕

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![React](https://img.shields.io/badge/React-18.x-blue.svg)](https://reactjs.org/)
[![Python](https://img.shields.io/badge/Python-3.8+-green.svg)](https://www.python.org/)
[![Kotlin](https://img.shields.io/badge/Kotlin-1.9+-purple.svg)](https://kotlinlang.org/)

</br>
<img width="1599" height="866" alt="image" src="https://github.com/user-attachments/assets/48b72a5f-c74c-4c52-9104-884c0303557c" />

</br>

An interactive queueing system analyzer that brings Markovian queue theory to life in a European coffee shop context. Experience the mathematics behind why your morning coffee line moves the way it does, with real-time simulations and comprehensive theoretical analysis.

## 🎯 Project Overview

This project implements a complete M/M/c queueing system analyzer with:

- **Theoretical Analysis**: Erlang C formula, Little's Law, steady-state metrics
- **Visual Simulation**: Animated European café with customers and baristas
- **Multi-Language Implementation**: React, Python, Kotlin, SQL, Dart, Julia
- **Real-Time Comparison**: Theory vs. simulation convergence
- **Birth-Death Process**: State diagram visualization with transition rates

### Key Features

✨ **Interactive Controls**: Adjust arrival rate (λ), service rate (μ), and server count (c) in real-time

📊 **Comprehensive Metrics**: 
- Queue length (Lq), wait time (Wq), system size (L), total time (W)
- System utilization (ρ), Erlang C probability
- State probabilities and birth-death transitions

🎨 **European Café Theme**: Immersive visual experience with animated customers in a charming European coffee shop setting

🔬 **Scientific Accuracy**: Implements exact Erlang C formula: `C(c,a) = (a^c/c!)/(∑(a^k/k!) + (a^c/c!)(c/(c-a)))`

## 📐 Mathematical Foundation

### Kendall Notation: M/M/c

- **M** (First): Markovian (Poisson) arrivals with rate λ
- **M** (Second): Markovian (Exponential) service times with rate μ
- **c** (Third): Number of parallel servers

### Key Formulas

**Traffic Intensity**: `a = λ/μ`

**Utilization**: `ρ = λ/(c·μ)` (must be < 1 for stability)

**Probability of Empty System (P₀)**:
```
P₀ = 1 / (∑(k=0 to c-1) a^k/k! + (a^c/c!) · c/(c-a))
```

**Erlang C (Probability of Waiting)**:
```
C(c,a) = (a^c/c! · P₀) / (1 - ρ)
```

**Average Queue Length**:
```
Lq = (ρ^c · ρ · P₀) / (c! · (1-ρ)²)
```

**Little's Law**:
```
Lq = λ · Wq
L = λ · W
W = Wq + 1/μ
```

## 🗂️ Project Structure

```
mmc-queue-analyzer/
│
├── README.md                          # This file
├── coffee_queue_analyzer.tsx          # TypeScript Interactive Artifact
├── queue_analyzer.py                  # Python FastAPI backend
├── QueueAnalyzer.kt                   # Kotlin implementation
├── queue_database.sql                 # SQL database schema
├── queue_simulator.dart               # Dart simulation engine
└── queue_analyzer.jl                  # Julia high-performance analyzer
```

## 🚀 Getting Started

### Prerequisites

- **React/HTML**: Modern web browser (Chrome, Firefox, Safari, Edge)
- **Python**: Python 3.8+ with `fastapi`, `uvicorn`, `numpy`, `scipy`
- **Kotlin**: JVM 11+ with Kotlin 1.9+
- **SQL**: MySQL/PostgreSQL/SQLite
- **Dart**: Dart SDK 2.17+
- **Julia**: Julia 1.8+ with `Distributions`, `Statistics`

### Installation & Running

#### React Interactive Artifact

Open `coffee_shop_queue_analyzer.html` directly in your browser. No installation needed!

```bash
# Simply open the file
open coffee_shop_queue_analyzer.html
```

#### Python FastAPI Backend

```bash
# Install dependencies
pip install fastapi uvicorn numpy scipy pydantic

# Run the server
python queue_analyzer.py

# API will be available at http://localhost:8000
# Documentation at http://localhost:8000/docs
```

**API Endpoints**:
- `POST /api/analyze` - Calculate theoretical metrics
- `POST /api/simulate` - Run queue simulation
- `GET /api/state-probabilities` - Get birth-death state probabilities

#### Kotlin Implementation

```bash
# Compile and run
kotlinc QueueAnalyzer.kt -include-runtime -d QueueAnalyzer.jar
java -jar QueueAnalyzer.jar
```

#### SQL Database

```bash
# MySQL
mysql -u username -p < queue_database.sql

# PostgreSQL
psql -U username -d database_name -f queue_database.sql

# SQLite
sqlite3 queue_analyzer.db < queue_database.sql
```

#### Dart Simulator

```bash
# Install Dart SDK first, then run
dart queue_simulator.dart
```

#### Julia Analyzer

```bash
# Install dependencies (first time only)
julia -e 'using Pkg; Pkg.add(["Distributions", "Statistics"])'

# Run the analyzer
julia queue_analyzer.jl
```

## 🎮 Usage Examples

### Interactive Web Interface

1. **Adjust Parameters**: Use sliders to modify λ, μ, and c
2. **Start Simulation**: Click "Start" to see customers arrive and get served
3. **Observe Metrics**: Watch theoretical vs. simulated metrics converge
4. **Test Scenarios**: Try ρ ≥ 1 to see system instability

### Python API Example

```python
import requests

# Analyze queue
response = requests.post('http://localhost:8000/api/analyze', json={
    "lambda_rate": 20.0,
    "mu_rate": 8.0,
    "c_servers": 3,
    "simulation_time": 100.0
})

metrics = response.json()
print(f"Average wait time: {metrics['wq']:.2f} minutes")
print(f"Probability of waiting: {metrics['erlang_c']*100:.1f}%")
```

### Kotlin Usage

```kotlin
val params = QueueParameters(
    lambdaRate = 20.0,
    muRate = 8.0,
    cServers = 3
)

val analyzer = MMcQueueAnalyzer(params)
val metrics = analyzer.analyzeQueue()

println("Wait time: ${metrics.wq} minutes")
println("Queue length: ${metrics.lq}")
```

### SQL Query Examples

```sql
-- Find optimal server count
SELECT c_servers, wq AS avg_wait_minutes, utilization_percent
FROM queue_configurations qc
JOIN theoretical_metrics tm ON qc.config_id = tm.config_id
WHERE lambda_rate = 20.0 AND mu_rate = 8.0
ORDER BY c_servers;

-- Compare theory vs simulation
SELECT * FROM metrics_comparison WHERE config_id = 1;
```

## 📊 Understanding the Metrics

| Metric | Symbol | Description | Units |
|--------|--------|-------------|-------|
| Utilization | ρ | Fraction of time servers are busy | % |
| Traffic Intensity | a | Average customers being served | customers |
| Erlang C | C(c,a) | Probability customer must wait | % |
| Queue Length | Lq | Average customers waiting | customers |
| Wait Time | Wq | Average time waiting in queue | minutes |
| System Size | L | Average customers in system | customers |
| System Time | W | Average total time in system | minutes |

### Stability Condition

The system is **stable** if and only if **ρ < 1**, meaning:

```
λ/(c·μ) < 1  ⟹  λ < c·μ
```

If ρ ≥ 1, the queue grows without bound (infinite wait times).

## 🧪 Example Scenarios

### Scenario 1: Morning Rush (Stable)
- λ = 20 customers/hour
- μ = 8 orders/hour/barista
- c = 3 baristas
- **Result**: ρ = 0.833, Wq ≈ 4.4 minutes ✅

### Scenario 2: Understaffed (Unstable)
- λ = 20 customers/hour
- μ = 8 orders/hour/barista  
- c = 2 baristas
- **Result**: ρ = 1.25, System unstable! ❌

### Scenario 3: Adding One Barista
- Change from c=3 to c=4
- **Result**: Wait time drops from 4.4 to 1.1 minutes (75% reduction!)

This demonstrates the **non-linear benefit** of adding capacity near saturation.

## 🔬 Technical Details

### Birth-Death Process

The M/M/c queue is a continuous-time Markov chain with:

**Birth Rates (Arrivals)**: `λₙ = λ` for all states n

**Death Rates (Departures)**:
```
μₙ = {
  n·μ     if n ≤ c
  c·μ     if n > c
}
```

### Steady-State Probabilities

For state n (n customers in system):

```
Pₙ = {
  (a^n / n!) · P₀           if n < c
  (a^n / (c! · c^(n-c))) · P₀   if n ≥ c
}
```

### Simulation Algorithm

1. Generate Poisson arrivals: interarrival ~ Exp(λ)
2. Track server availability array
3. Assign to earliest available server
4. Generate service time ~ Exp(μ)
5. Record wait time = service_start - arrival
6. Calculate statistics over all customers

## 🎨 Visual Design

The interactive artifact features:

- **European Café Aesthetic**: Warm brown tones, wooden textures
- **Animated Customers**: Colorful avatars moving through the space
- **Barista Stations**: Visual representation of c servers
- **Real-Time Updates**: Live queue length and served count
- **Responsive Controls**: Professional control panel with clear typography (min 16px)

## 📈 Performance Characteristics

| Implementation | Speed | Best For |
|----------------|-------|----------|
| Julia | ⚡⚡⚡⚡⚡ | Large-scale simulations, scientific computing |
| Kotlin | ⚡⚡⚡⚡ | JVM applications, Android integration |
| Python | ⚡⚡⚡ | API services, data analysis, prototyping |
| Dart | ⚡⚡⚡ | Flutter apps, cross-platform mobile |
| SQL | ⚡⚡ | Data persistence, historical analysis |
| React | ⚡⚡⚡ | Interactive visualizations, web interfaces |

## 🧮 Extensions & Future Work

- **M/M/c/K**: Finite capacity systems
- **M/M/c with priorities**: Customer classes
- **Network of queues**: Jackson networks
- **Non-Markovian**: M/G/1, G/G/c systems
- **Optimization**: Minimize cost = c·server_cost + customer_wait_cost
- **Machine Learning**: Predict optimal staffing from historical data

---

**⭐ Star this repository if you find it helpful!**
