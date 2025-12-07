import 'dart:math';

class QueueParameters {
  final double lambdaRate;
  final double muRate;
  final int cServers;

  QueueParameters({
    required this.lambdaRate,
    required this.muRate,
    required this.cServers,
  });
}

class QueueMetrics {
  final double rho;
  final double trafficIntensity;
  final double p0;
  final double erlangC;
  final double lq;
  final double wq;
  final double l;
  final double w;
  final double utilization;
  final bool stable;

  QueueMetrics({
    required this.rho,
    required this.trafficIntensity,
    required this.p0,
    required this.erlangC,
    required this.lq,
    required this.wq,
    required this.l,
    required this.w,
    required this.utilization,
    required this.stable,
  });

  @override
  String toString() {
    return '''
QueueMetrics:
  Utilization (ρ): ${(utilization).toStringAsFixed(2)}%
  Traffic Intensity: ${trafficIntensity.toStringAsFixed(2)}
  P0: ${p0.toStringAsFixed(4)}
  Erlang C: ${(erlangC * 100).toStringAsFixed(2)}%
  Lq: ${lq.toStringAsFixed(2)}
  Wq: ${wq.toStringAsFixed(2)} minutes
  L: ${l.toStringAsFixed(2)}
  W: ${w.toStringAsFixed(2)} minutes
  Stable: $stable
    ''';
  }
}

class Customer {
  final int id;
  final double arrivalTime;
  double? serviceStartTime;
  double? serviceEndTime;
  int? serverId;

  Customer({
    required this.id,
    required this.arrivalTime,
  });

  double get waitTime => 
      serviceStartTime != null ? serviceStartTime! - arrivalTime : 0.0;
  
  double get serviceTime =>
      (serviceStartTime != null && serviceEndTime != null) 
          ? serviceEndTime! - serviceStartTime! 
          : 0.0;
  
  double get totalTime =>
      serviceEndTime != null ? serviceEndTime! - arrivalTime : 0.0;
}

class SimulationResult {
  final int totalArrivals;
  final int totalServed;
  final double avgWaitTime;
  final double maxWaitTime;
  final double avgQueueLength;
  final int maxQueueLength;
  final List<Customer> customers;

  SimulationResult({
    required this.totalArrivals,
    required this.totalServed,
    required this.avgWaitTime,
    required this.maxWaitTime,
    required this.avgQueueLength,
    required this.maxQueueLength,
    required this.customers,
  });

  @override
  String toString() {
    return '''
SimulationResult:
  Total Arrivals: $totalArrivals
  Total Served: $totalServed
  Avg Wait Time: ${avgWaitTime.toStringAsFixed(2)} minutes
  Max Wait Time: ${maxWaitTime.toStringAsFixed(2)} minutes
  Avg Queue Length: ${avgQueueLength.toStringAsFixed(2)}
  Max Queue Length: $maxQueueLength
    ''';
  }
}

class MMcQueueAnalyzer {
  final QueueParameters params;
  final Random _random = Random();

  MMcQueueAnalyzer(this.params);

  double get lambda => params.lambdaRate;
  double get mu => params.muRate;
  int get c => params.cServers;
  double get rho => lambda / (c * mu);
  double get trafficIntensity => lambda / mu;

  int _factorial(int n) {
    if (n <= 1) return 1;
    return List.generate(n, (i) => i + 1).reduce((a, b) => a * b);
  }

  double _calculateP0() {
    double sum = 0.0;
    for (int k = 0; k < c; k++) {
      sum += pow(trafficIntensity, k) / _factorial(k);
    }
    double lastTerm = (pow(trafficIntensity, c) / _factorial(c)) * 
                      (c / (c - trafficIntensity));
    return 1.0 / (sum + lastTerm);
  }

  double _calculateErlangC() {
    if (rho >= 1.0) return 1.0;
    double p0 = _calculateP0();
    double numerator = pow(trafficIntensity, c) / _factorial(c);
    double denominator = 1 - rho;
    return (numerator * p0) / denominator;
  }

  QueueMetrics analyzeQueue() {
    if (rho >= 1.0) {
      return QueueMetrics(
        rho: rho,
        trafficIntensity: trafficIntensity,
        p0: 0.0,
        erlangC: 1.0,
        lq: double.infinity,
        wq: double.infinity,
        l: double.infinity,
        w: double.infinity,
        utilization: rho * 100,
        stable: false,
      );
    }

    double p0 = _calculateP0();
    double erlangC = _calculateErlangC();
    double wq = (erlangC / (c * mu - lambda)) * 60;
    double lq = lambda * (wq / 60);
    double w = wq + (60 / mu);
    double l = lambda * (w / 60);

    return QueueMetrics(
      rho: rho,
      trafficIntensity: trafficIntensity,
      p0: p0,
      erlangC: erlangC,
      lq: lq,
      wq: wq,
      l: l,
      w: w,
      utilization: rho * 100,
      stable: true,
    );
  }

  Map<int, double> getStateProbabilities({int maxStates = 20}) {
    if (rho >= 1.0) return {};

    double p0 = _calculateP0();
    Map<int, double> probabilities = {};

    for (int n = 0; n <= maxStates; n++) {
      double pn;
      if (n < c) {
        pn = (pow(trafficIntensity, n) / _factorial(n)) * p0;
      } else {
        pn = (pow(trafficIntensity, n) / 
              (_factorial(c) * pow(c, n - c))) * p0;
      }
      probabilities[n] = pn;
    }

    return probabilities;
  }

  double _exponential(double rate) {
    return -log(_random.nextDouble()) / rate;
  }

  SimulationResult simulate({double duration = 100.0}) {
    List<Customer> customers = [];
    List<double> serverBusyUntil = List.filled(c, 0.0);
    
    // Generate arrivals
    double currentTime = 0.0;
    int customerId = 0;
    
    while (currentTime < duration) {
      double interarrival = _exponential(lambda);
      currentTime += interarrival;
      
      if (currentTime < duration) {
        customers.add(Customer(
          id: customerId++,
          arrivalTime: currentTime,
        ));
      }
    }

    // Process customers through queue
    List<int> queueLengthHistory = [];
    
    for (var customer in customers) {
      // Find server that will be available earliest
      int earliestServerIdx = 0;
      double earliestTime = serverBusyUntil[0];
      
      for (int i = 1; i < c; i++) {
        if (serverBusyUntil[i] < earliestTime) {
          earliestTime = serverBusyUntil[i];
          earliestServerIdx = i;
        }
      }

      // Customer starts service when both arrived and server available
      customer.serviceStartTime = max(
        customer.arrivalTime, 
        serverBusyUntil[earliestServerIdx]
      );
      
      // Generate service time
      double serviceTime = _exponential(mu);
      customer.serviceEndTime = customer.serviceStartTime! + serviceTime;
      customer.serverId = earliestServerIdx;
      
      // Update server availability
      serverBusyUntil[earliestServerIdx] = customer.serviceEndTime!;
      
      // Track queue length at arrival
      int queueLength = customers
          .where((c) => 
              c.arrivalTime < customer.arrivalTime && 
              c.serviceStartTime! > customer.arrivalTime)
          .length;
      queueLengthHistory.add(queueLength);
    }

    // Calculate statistics
    List<double> waitTimes = customers
        .map((c) => c.waitTime * 60)
        .toList();
    
    double avgWaitTime = waitTimes.isEmpty 
        ? 0.0 
        : waitTimes.reduce((a, b) => a + b) / waitTimes.length;
    
    double maxWaitTime = waitTimes.isEmpty 
        ? 0.0 
        : waitTimes.reduce(max);
    
    double avgQueueLength = queueLengthHistory.isEmpty
        ? 0.0
        : queueLengthHistory.reduce((a, b) => a + b) / queueLengthHistory.length;
    
    int maxQueueLength = queueLengthHistory.isEmpty
        ? 0
        : queueLengthHistory.reduce(max);

    return SimulationResult(
      totalArrivals: customers.length,
      totalServed: customers.length,
      avgWaitTime: avgWaitTime,
      maxWaitTime: maxWaitTime,
      avgQueueLength: avgQueueLength,
      maxQueueLength: maxQueueLength,
      customers: customers,
    );
  }
}

void main() {
  print('=== M/M/c Queue Analyzer (Dart Implementation) ===\n');

  // Define queue parameters
  final params = QueueParameters(
    lambdaRate: 20.0,
    muRate: 8.0,
    cServers: 3,
  );

  print('Queue Configuration:');
  print('  λ (arrival rate): ${params.lambdaRate} customers/hour');
  print('  μ (service rate): ${params.muRate} orders/hour/server');
  print('  c (servers): ${params.cServers}\n');

  // Create analyzer
  final analyzer = MMcQueueAnalyzer(params);

  // Theoretical analysis
  print('--- Theoretical Analysis ---');
  final metrics = analyzer.analyzeQueue();
  print(metrics);

  // State probabilities
  print('--- State Probabilities ---');
  final probabilities = analyzer.getStateProbabilities(maxStates: 10);
  probabilities.forEach((state, prob) {
    print('  P($state) = ${prob.toStringAsFixed(6)}');
  });
  print('');

  // Run simulation
  print('--- Simulation (100 hours) ---');
  final simResult = analyzer.simulate(duration: 100.0);
  print(simResult);

  // Comparison
  print('--- Theoretical vs Simulated Comparison ---');
  print('  Wait Time - Theory: ${metrics.wq.toStringAsFixed(2)} min, '
        'Sim: ${simResult.avgWaitTime.toStringAsFixed(2)} min');
  print('  Queue Length - Theory: ${metrics.lq.toStringAsFixed(2)}, '
        'Sim: ${simResult.avgQueueLength.toStringAsFixed(2)}');
  print('  Difference: ${((simResult.avgWaitTime - metrics.wq) / metrics.wq * 100).toStringAsFixed(2)}%');

  // Test different configurations
  print('\n--- Impact of Adding Servers ---');
  for (int servers = 2; servers <= 5; servers++) {
    final testParams = QueueParameters(
      lambdaRate: 20.0,
      muRate: 8.0,
      cServers: servers,
    );
    final testAnalyzer = MMcQueueAnalyzer(testParams);
    final testMetrics = testAnalyzer.analyzeQueue();
    
    print('c=$servers: Wq=${testMetrics.wq.toStringAsFixed(2)} min, '
          'ρ=${testMetrics.utilization.toStringAsFixed(1)}%, '
          'Stable=${testMetrics.stable}');
  }
}