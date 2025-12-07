using Distributions
using Statistics
using Printf

"""
M/M/c Queue Analyzer in Julia
Implements queueing theory analysis with high-performance simulation
"""

struct QueueParameters
    λ::Float64  # Arrival rate (customers/hour)
    μ::Float64  # Service rate (orders/hour/server)
    c::Int      # Number of servers
end

struct QueueMetrics
    ρ::Float64              # Utilization
    a::Float64              # Traffic intensity
    P0::Float64             # Probability of empty system
    C::Float64              # Erlang C (probability of waiting)
    Lq::Float64             # Average queue length
    Wq::Float64             # Average wait time (minutes)
    L::Float64              # Average customers in system
    W::Float64              # Average time in system (minutes)
    utilization::Float64    # Utilization percentage
    stable::Bool            # System stability
end

struct SimulationResult
    total_arrivals::Int
    total_served::Int
    avg_wait_time::Float64
    max_wait_time::Float64
    avg_queue_length::Float64
    max_queue_length::Int
    wait_time_samples::Vector{Float64}
end

"""
Calculate P0 - probability of empty system
"""
function calculate_P0(a::Float64, c::Int)::Float64
    sum_term = sum(a^k / factorial(k) for k in 0:(c-1))
    last_term = (a^c / factorial(c)) * (c / (c - a))
    return 1.0 / (sum_term + last_term)
end

"""
Calculate Erlang C - probability of waiting
C(c,a) = (a^c/c!) / (∑(a^k/k!) + (a^c/c!)(c/(c-a)))
"""
function calculate_erlang_c(a::Float64, c::Int, ρ::Float64)::Float64
    if ρ >= 1.0
        return 1.0
    end
    
    P0 = calculate_P0(a, c)
    numerator = a^c / factorial(c)
    denominator = 1 - ρ
    return (numerator * P0) / denominator
end

"""
Analyze M/M/c queue system and return theoretical metrics
"""
function analyze_queue(params::QueueParameters)::QueueMetrics
    λ, μ, c = params.λ, params.μ, params.c
    
    # Calculate basic parameters
    ρ = λ / (c * μ)
    a = λ / μ
    
    # Check stability
    stable = ρ < 1.0
    
    if !stable
        return QueueMetrics(
            ρ, a, 0.0, 1.0,
            Inf, Inf, Inf, Inf,
            ρ * 100, false
        )
    end
    
    # Calculate metrics
    P0 = calculate_P0(a, c)
    C = calculate_erlang_c(a, c, ρ)
    
    # Little's Law applications
    Wq = (C / (c * μ - λ)) * 60  # Average wait time (minutes)
    Lq = λ * (Wq / 60)            # Average queue length
    W = Wq + (60 / μ)             # Average time in system (minutes)
    L = λ * (W / 60)              # Average customers in system
    
    return QueueMetrics(
        ρ, a, P0, C,
        Lq, Wq, L, W,
        ρ * 100, true
    )
end

"""
Calculate state probabilities for birth-death process
"""
function state_probabilities(params::QueueParameters, max_states::Int=20)::Dict{Int, Float64}
    λ, μ, c = params.λ, params.μ, params.c
    ρ = λ / (c * μ)
    a = λ / μ
    
    if ρ >= 1.0
        return Dict{Int, Float64}()
    end
    
    P0 = calculate_P0(a, c)
    probs = Dict{Int, Float64}()
    
    for n in 0:max_states
        if n < c
            Pn = (a^n / factorial(n)) * P0
        else
            Pn = (a^n / (factorial(c) * c^(n - c))) * P0
        end
        probs[n] = Pn
    end
    
    return probs
end

"""
Generate birth-death process transition rates
"""
function birth_death_transitions(params::QueueParameters, max_states::Int=10)
    λ, μ, c = params.λ, params.μ, params.c
    
    transitions = []
    
    for n in 0:max_states
        # Birth (arrival) transitions
        push!(transitions, (from=n, to=n+1, rate=λ, type="arrival"))
        
        # Death (departure) transitions
        if n > 0
            service_rate = n <= c ? n * μ : c * μ
            push!(transitions, (from=n, to=n-1, rate=service_rate, type="departure"))
        end
    end
    
    return transitions
end

"""
Simulate M/M/c queue system using discrete event simulation
"""
function simulate_queue(params::QueueParameters; duration::Float64=100.0)::SimulationResult
    λ, μ, c = params.λ, params.μ, params.c
    
    # Generate arrival times (Poisson process)
    arrivals = Float64[]
    current_time = 0.0
    
    while current_time < duration
        interarrival = rand(Exponential(1/λ))
        current_time += interarrival
        if current_time < duration
            push!(arrivals, current_time)
        end
    end
    
    # Track server availability
    server_busy_until = zeros(Float64, c)
    wait_times = Float64[]
    queue_lengths = Int[]
    
    # Process each customer
    for arrival_time in arrivals
        # Find server that will be free earliest
        earliest_server = argmin(server_busy_until)
        service_start = max(arrival_time, server_busy_until[earliest_server])
        wait_time = service_start - arrival_time
        push!(wait_times, wait_time)
        
        # Calculate queue length at arrival
        queue_length = count(t -> t > arrival_time, server_busy_until)
        push!(queue_lengths, queue_length)
        
        # Generate service time and update server
        service_time = rand(Exponential(1/μ))
        server_busy_until[earliest_server] = service_start + service_time
    end
    
    # Convert to minutes
    wait_times_min = wait_times .* 60
    
    return SimulationResult(
        length(arrivals),
        length(wait_times),
        mean(wait_times_min),
        maximum(wait_times_min),
        mean(queue_lengths),
        maximum(queue_lengths),
        wait_times_min
    )
end

"""
Run multiple simulations and aggregate results
"""
function monte_carlo_simulation(params::QueueParameters; 
                                num_runs::Int=10, 
                                duration::Float64=100.0)
    results = [simulate_queue(params, duration=duration) for _ in 1:num_runs]
    
    avg_wait = mean(r.avg_wait_time for r in results)
    std_wait = std(r.avg_wait_time for r in results)
    avg_queue = mean(r.avg_queue_length for r in results)
    
    return (
        mean_wait=avg_wait,
        std_wait=std_wait,
        mean_queue=avg_queue,
        results=results
    )
end

"""
Display metrics in formatted table
"""
function display_metrics(metrics::QueueMetrics)
    println("\n" * "="^50)
    println("THEORETICAL METRICS")
    println("="^50)
    @printf("Utilization (ρ):          %.2f%%\n", metrics.utilization)
    @printf("Traffic Intensity (a):    %.2f\n", metrics.a)
    @printf("P0 (empty system):        %.6f\n", metrics.P0)
    @printf("Erlang C (prob waiting):  %.2f%%\n", metrics.C * 100)
    @printf("Lq (avg queue length):    %.2f customers\n", metrics.Lq)
    @printf("Wq (avg wait time):       %.2f minutes\n", metrics.Wq)
    @printf("L (avg in system):        %.2f customers\n", metrics.L)
    @printf("W (avg time in system):   %.2f minutes\n", metrics.W)
    @printf("System Stable:            %s\n", metrics.stable ? "Yes" : "No")
    println("="^50)
end

"""
Display simulation results
"""
function display_simulation(result::SimulationResult)
    println("\n" * "="^50)
    println("SIMULATION RESULTS")
    println("="^50)
    @printf("Total Arrivals:           %d\n", result.total_arrivals)
    @printf("Total Served:             %d\n", result.total_served)
    @printf("Avg Wait Time:            %.2f minutes\n", result.avg_wait_time)
    @printf("Max Wait Time:            %.2f minutes\n", result.max_wait_time)
    @printf("Avg Queue Length:         %.2f customers\n", result.avg_queue_length)
    @printf("Max Queue Length:         %d customers\n", result.max_queue_length)
    println("="^50)
end

"""
Main analysis function
"""
function main()
    println("\n" * "="^70)
    println("M/M/c QUEUE ANALYZER - Coffee Shop Edition")
    println("="^70)
    
    # Define queue parameters
    params = QueueParameters(20.0, 8.0, 3)
    
    println("\nQueue Configuration:")
    @printf("  λ (arrival rate):     %.1f customers/hour\n", params.λ)
    @printf("  μ (service rate):     %.1f orders/hour/server\n", params.μ)
    @printf("  c (servers):          %d\n", params.c)
    
    # Theoretical analysis
    metrics = analyze_queue(params)
    display_metrics(metrics)
    
    # State probabilities
    println("\nSTATE PROBABILITIES (Birth-Death Process):")
    println("-"^50)
    probs = state_probabilities(params, 10)
    for n in sort(collect(keys(probs)))
        @printf("P(%2d) = %.6f", n, probs[n])
        println("  ", "█"^round(Int, probs[n] * 100))
    end
    
    # Single simulation
    println("\nRUNNING SINGLE SIMULATION (100 hours)...")
    sim_result = simulate_queue(params, duration=100.0)
    display_simulation(sim_result)
    
    # Comparison
    println("\nTHEORETICAL vs SIMULATED:")
    println("-"^50)
    @printf("Wait Time:  Theory = %.2f min, Sim = %.2f min (%.1f%% diff)\n",
            metrics.Wq, sim_result.avg_wait_time,
            abs(sim_result.avg_wait_time - metrics.Wq) / metrics.Wq * 100)
    @printf("Queue Len:  Theory = %.2f, Sim = %.2f (%.1f%% diff)\n",
            metrics.Lq, sim_result.avg_queue_length,
            abs(sim_result.avg_queue_length - metrics.Lq) / metrics.Lq * 100)
    
    # Test different server counts
    println("\n" * "="^70)
    println("IMPACT OF ADDING SERVERS")
    println("="^70)
    println(@sprintf("%-8s %-12s %-12s %-12s %-8s", 
                    "Servers", "Wait Time", "Queue Len", "Utilization", "Stable"))
    println("-"^70)
    
    for c in 2:6
        test_params = QueueParameters(params.λ, params.μ, c)
        test_metrics = analyze_queue(test_params)
        println(@sprintf("%-8d %-12.2f %-12.2f %-12.1f%% %-8s",
                        c, test_metrics.Wq, test_metrics.Lq,
                        test_metrics.utilization, 
                        test_metrics.stable ? "Yes" : "No"))
    end
    
    # Monte Carlo simulation
    println("\n" * "="^70)
    println("MONTE CARLO SIMULATION (10 runs)")
    println("="^70)
    mc_results = monte_carlo_simulation(params, num_runs=10, duration=100.0)
    @printf("Mean Wait Time:     %.2f ± %.2f minutes\n", 
            mc_results.mean_wait, mc_results.std_wait)
    @printf("Mean Queue Length:  %.2f customers\n", mc_results.mean_queue)
    @printf("Theoretical Wq:     %.2f minutes\n", metrics.Wq)
    
    println("\n" * "="^70)
    println("Analysis Complete!")
    println("="^70 * "\n")
end

# Run the main analysis
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end