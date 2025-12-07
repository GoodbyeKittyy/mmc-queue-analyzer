import kotlin.math.pow
import kotlin.math.exp
import kotlin.random.Random

data class QueueParameters(
    val lambdaRate: Double,
    val muRate: Double,
    val cServers: Int
)

data class QueueMetrics(
    val rho: Double,
    val trafficIntensity: Double,
    val p0: Double,
    val erlangC: Double,
    val lq: Double,
    val wq: Double,
    val l: Double,
    val w: Double,
    val utilization: Double,
    val stable: Boolean
)

data class StateTransition(
    val fromState: Int,
    val toState: Int,
    val rate: Double,
    val type: String
)

class MMcQueueAnalyzer(private val params: QueueParameters) {
    
    private val lambda = params.lambdaRate
    private val mu = params.muRate
    private val c = params.cServers
    private val rho = lambda / (c * mu)
    private val trafficIntensity = lambda / mu
    
    private fun factorial(n: Int): Double {
        if (n <= 1) return 1.0
        return (2..n).fold(1.0) { acc, i -> acc * i }
    }
    
    private fun calculateP0(): Double {
        val sumTerm = (0 until c).sumOf { k ->
            trafficIntensity.pow(k) / factorial(k)
        }
        val lastTerm = (trafficIntensity.pow(c) / factorial(c)) * (c / (c - trafficIntensity))
        return 1.0 / (sumTerm + lastTerm)
    }
    
    private fun calculateErlangC(): Double {
        if (rho >= 1.0) return 1.0
        val p0 = calculateP0()
        val numerator = trafficIntensity.pow(c) / factorial(c)
        val denominator = 1 - rho
        return (numerator * p0) / denominator
    }
    
    fun analyzeQueue(): QueueMetrics {
        if (rho >= 1.0) {
            return QueueMetrics(
                rho = rho,
                trafficIntensity = trafficIntensity,
                p0 = 0.0,
                erlangC = 1.0,
                lq = Double.POSITIVE_INFINITY,
                wq = Double.POSITIVE_INFINITY,
                l = Double.POSITIVE_INFINITY,
                w = Double.POSITIVE_INFINITY,
                utilization = rho * 100,
                stable = false
            )
        }
        
        val p0 = calculateP0()
        val erlangC = calculateErlangC()
        
        val wq = (erlangC / (c * mu - lambda)) * 60
        val lq = lambda * (wq / 60)
        val w = wq + (60 / mu)
        val l = lambda * (w / 60)
        
        return QueueMetrics(
            rho = rho,
            trafficIntensity = trafficIntensity,
            p0 = p0,
            erlangC = erlangC,
            lq = lq,
            wq = wq,
            l = l,
            w = w,
            utilization = rho * 100,
            stable = true
        )
    }
    
    fun getStateProbabilities(maxStates: Int = 20): Map<Int, Double> {
        if (rho >= 1.0) return emptyMap()
        
        val p0 = calculateP0()
        return (0..maxStates).associateWith { n ->
            when {
                n < c -> (trafficIntensity.pow(n) / factorial(n)) * p0
                else -> (trafficIntensity.pow(n) / (factorial(c) * c.toDouble().pow(n - c))) * p0
            }
        }
    }
    
    fun getBirthDeathTransitions(maxStates: Int = 10): List<StateTransition> {
        val transitions = mutableListOf<StateTransition>()
        
        for (n in 0..maxStates) {
            transitions.add(StateTransition(n, n + 1, lambda, "arrival"))
            
            if (n > 0) {
                val serviceRate = if (n <= c) n * mu else c * mu
                transitions.add(StateTransition(n, n - 1, serviceRate, "departure"))
            }
        }
        
        return transitions
    }
    
    fun simulateQueue(duration: Double): SimulationResult {
        val arrivals = mutableListOf<Double>()
        var currentTime = 0.0
        
        while (currentTime < duration) {
            val interarrival = -Math.log(Random.nextDouble()) / lambda
            currentTime += interarrival
            if (currentTime < duration) {
                arrivals.add(currentTime)
            }
        }
        
        val serversBusyUntil = DoubleArray(c) { 0.0 }
        val waitTimes = mutableListOf<Double>()
        
        for (arrivalTime in arrivals) {
            val earliestServerIdx = serversBusyUntil.indices.minByOrNull { serversBusyUntil[it] } ?: 0
            val serviceStart = maxOf(arrivalTime, serversBusyUntil[earliestServerIdx])
            val waitTime = serviceStart - arrivalTime
            waitTimes.add(waitTime)
            
            val serviceDuration = -Math.log(Random.nextDouble()) / mu
            serversBusyUntil[earliestServerIdx] = serviceStart + serviceDuration
        }
        
        return SimulationResult(
            totalArrivals = arrivals.size,
            totalServed = waitTimes.size,
            avgWaitTimeMinutes = waitTimes.average() * 60,
            maxWaitTimeMinutes = waitTimes.maxOrNull()?.let { it * 60 } ?: 0.0
        )
    }
}

data class SimulationResult(
    val totalArrivals: Int,
    val totalServed: Int,
    val avgWaitTimeMinutes: Double,
    val maxWaitTimeMinutes: Double
)

fun main() {
    val params = QueueParameters(
        lambdaRate = 20.0,
        muRate = 8.0,
        cServers = 3
    )
    
    val analyzer = MMcQueueAnalyzer(params)
    
    println("=== M/M/c Queue Analysis ===")
    println("Lambda: ${params.lambdaRate} customers/hour")
    println("Mu: ${params.muRate} orders/hour/server")
    println("c: ${params.cServers} servers")
    println()
    
    val metrics = analyzer.analyzeQueue()
    println("Theoretical Metrics:")
    println("  Utilization (rho): ${"%.2f".format(metrics.utilization)}%")
    println("  Traffic Intensity: ${"%.2f".format(metrics.trafficIntensity)}")
    println("  P0: ${"%.4f".format(metrics.p0)}")
    println("  Erlang C: ${"%.2f".format(metrics.erlangC * 100)}%")
    println("  Lq: ${"%.2f".format(metrics.lq)}")
    println("  Wq: ${"%.2f".format(metrics.wq)} minutes")
    println("  L: ${"%.2f".format(metrics.l)}")
    println("  W: ${"%.2f".format(metrics.w)} minutes")
    println("  Stable: ${metrics.stable}")
    println()
    
    val stateProbabilities = analyzer.getStateProbabilities(10)
    println("State Probabilities:")
    stateProbabilities.forEach { (state, prob) ->
        println("  P($state) = ${"%.4f".format(prob)}")
    }
    println()
    
    val transitions = analyzer.getBirthDeathTransitions(5)
    println("Birth-Death Process Transitions:")
    transitions.forEach { transition ->
        println("  ${transition.fromState} -> ${transition.toState}: ${transition.rate} (${transition.type})")
    }
    println()
    
    val simResult = analyzer.simulateQueue(100.0)
    println("Simulation Results (100 hours):")
    println("  Total Arrivals: ${simResult.totalArrivals}")
    println("  Total Served: ${simResult.totalServed}")
    println("  Avg Wait Time: ${"%.2f".format(simResult.avgWaitTimeMinutes)} minutes")
    println("  Max Wait Time: ${"%.2f".format(simResult.maxWaitTimeMinutes)} minutes")
}