import React, { useState, useEffect, useRef } from 'react';
import { Coffee, Users, Clock, TrendingUp, Play, Pause, RotateCcw, Settings } from 'lucide-react';

const CoffeeShopQueueAnalyzer = () => {
  const [lambda, setLambda] = useState(20);
  const [mu, setMu] = useState(8);
  const [c, setC] = useState(3);
  const [simRunning, setSimRunning] = useState(false);
  const [simTime, setSimTime] = useState(0);
  const [customers, setCustomers] = useState([]);
  const [nextCustomerId, setNextCustomerId] = useState(1);
  const [servedCount, setServedCount] = useState(0);
  const [totalWaitTime, setTotalWaitTime] = useState(0);
  const [showControls, setShowControls] = useState(true);
  const [simSpeed, setSimSpeed] = useState(1);
  const [waitTimeHistory, setWaitTimeHistory] = useState([]);
  
  const canvasRef = useRef(null);
  const animationRef = useRef(null);

  const rho = lambda / (c * mu);
  const trafficIntensity = lambda / mu;

  const factorial = (n) => {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
  };

  const calculateP0 = () => {
    let sum = 0;
    for (let k = 0; k < c; k++) {
      sum += Math.pow(trafficIntensity, k) / factorial(k);
    }
    const term2 = (Math.pow(trafficIntensity, c) / factorial(c)) * (c / (c - trafficIntensity));
    return 1 / (sum + term2);
  };

  const calculateErlangC = () => {
    if (rho >= 1) return 1;
    const P0 = calculateP0();
    const numerator = Math.pow(trafficIntensity, c) / factorial(c);
    const denominator = 1 - rho;
    return (numerator * P0) / denominator;
  };

  const calculateMetrics = () => {
    if (rho >= 1) {
      return {
        Lq: Infinity,
        Wq: Infinity,
        L: Infinity,
        W: Infinity,
        utilization: rho * 100,
        erlangC: 1
      };
    }

    const erlangC = calculateErlangC();
    const Wq = (erlangC / (c * mu - lambda)) * 60;
    const Lq = lambda * (Wq / 60);
    const W = Wq + (60 / mu);
    const L = lambda * (W / 60);

    return {
      Lq: Lq.toFixed(2),
      Wq: Wq.toFixed(2),
      L: L.toFixed(2),
      W: W.toFixed(2),
      utilization: (rho * 100).toFixed(1),
      erlangC: (erlangC * 100).toFixed(1)
    };
  };

  const metrics = calculateMetrics();

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    const width = canvas.width = window.innerWidth;
    const height = canvas.height = window.innerHeight;

    const baristaY = 120;
    const queueStartY = 220;
    const exitY = height - 150;
    const columnWidth = Math.min(180, (width - 100) / c);

    const drawCafe = () => {
      // Background
      ctx.fillStyle = '#2d1810';
      ctx.fillRect(0, 0, width, height);

      // Title at top
      ctx.fillStyle = '#f4e4c1';
      ctx.font = 'bold 36px Georgia';
      ctx.textAlign = 'center';
      ctx.fillText('☕ Café de la Queue ☕', width / 2, 50);

      // Draw barista stations and queues for each column
      const startX = (width - (c * columnWidth)) / 2;
      
      for (let i = 0; i < c; i++) {
        const x = startX + i * columnWidth + columnWidth / 2;
        
        // Barista station at top
        ctx.fillStyle = '#d4a574';
        ctx.fillRect(x - 50, baristaY - 40, 100, 80);
        ctx.fillStyle = '#8b6f47';
        ctx.fillRect(x - 40, baristaY - 30, 80, 60);
        
        // Barista label
        ctx.fillStyle = '#2d1810';
        ctx.font = 'bold 20px Arial';
        ctx.textAlign = 'center';
        ctx.fillText(`Barista ${i + 1}`, x, baristaY - 45);
        
        // Coffee machine
        ctx.fillStyle = '#5a4a3a';
        ctx.fillRect(x - 20, baristaY - 10, 40, 30);
        ctx.font = 'bold 24px Arial';
        ctx.fillText('☕', x, baristaY + 15);
        
        // Queue column line
        ctx.strokeStyle = '#fbbf24';
        ctx.lineWidth = 2;
        ctx.setLineDash([5, 5]);
        ctx.beginPath();
        ctx.moveTo(x, queueStartY);
        ctx.lineTo(x, exitY - 50);
        ctx.stroke();
        ctx.setLineDash([]);
        
        // Queue label
        ctx.fillStyle = '#f4e4c1';
        ctx.font = 'bold 16px Arial';
        ctx.fillText('↓ Queue ↓', x, queueStartY - 10);
      }

      // Entrance area (bottom)
      ctx.fillStyle = '#fbbf24';
      ctx.font = 'bold 28px Arial';
      ctx.textAlign = 'center';
      ctx.fillText('→ ENTRANCE →', width / 2, height - 50);
      
      // Exit area with clear path
      ctx.fillStyle = '#8b6f47';
      ctx.fillRect(width - 150, height / 2 - 100, 150, 200);
      
      // Exit door
      ctx.fillStyle = '#4ade80';
      ctx.fillRect(width - 140, height / 2 - 80, 120, 160);
      
      // Exit sign
      ctx.fillStyle = '#2d1810';
      ctx.font = 'bold 32px Arial';
      ctx.textAlign = 'center';
      ctx.fillText('EXIT', width - 80, height / 2 - 20);
      ctx.font = 'bold 40px Arial';
      ctx.fillText('→', width - 80, height / 2 + 30);
      
      // Exit path arrows
      ctx.fillStyle = '#4ade80';
      ctx.font = 'bold 36px Arial';
      for (let i = 0; i < 4; i++) {
        ctx.fillText('→', width - 300 + i * 50, height / 2);
      }

      // Draw customers
      customers.forEach((customer) => {
        // Customer circle
        ctx.fillStyle = customer.color;
        ctx.beginPath();
        ctx.arc(customer.x, customer.y, 25, 0, Math.PI * 2);
        ctx.fill();
        
        // Border
        ctx.strokeStyle = '#2d1810';
        ctx.lineWidth = 3;
        ctx.stroke();
        
        // Customer emoji
        ctx.font = 'bold 30px Arial';
        ctx.textAlign = 'center';
        ctx.fillText('👤', customer.x, customer.y + 10);
        
        // Customer ID label (to the right)
        ctx.fillStyle = '#2d1810';
        ctx.fillRect(customer.x + 30, customer.y - 12, 45, 24);
        ctx.fillStyle = '#fff';
        ctx.font = 'bold 14px Arial';
        ctx.textAlign = 'left';
        ctx.fillText(`#${customer.displayId}`, customer.x + 35, customer.y + 5);
        
        // Status label (below)
        const statusText = customer.status === 'waiting' ? 'Wait' : 
                          customer.status === 'serving' ? 'Serve' : 
                          (customer.status === 'exiting_down' || customer.status === 'exiting_right') ? 'Exit' : 'Walk';
        const statusColor = customer.status === 'waiting' ? '#fbbf24' : 
                           customer.status === 'serving' ? '#4ade80' : 
                           (customer.status === 'exiting_down' || customer.status === 'exiting_right') ? '#60a5fa' : '#a78bfa';
        
        ctx.fillStyle = statusColor;
        ctx.fillRect(customer.x - 28, customer.y + 30, 56, 20);
        ctx.fillStyle = '#2d1810';
        ctx.font = 'bold 12px Arial';
        ctx.textAlign = 'center';
        ctx.fillText(statusText, customer.x, customer.y + 44);
      });

      // Queue statistics
      const queueCounts = {};
      for (let i = 0; i < c; i++) {
        queueCounts[i] = customers.filter(c => c.queueColumn === i && c.status === 'waiting').length;
      }
      
      const totalQueue = Object.values(queueCounts).reduce((a, b) => a + b, 0);
      
      ctx.fillStyle = 'rgba(74, 58, 42, 0.9)';
      ctx.fillRect(20, 80, 250, 60);
      ctx.fillStyle = '#fbbf24';
      ctx.font = 'bold 22px Arial';
      ctx.textAlign = 'left';
      ctx.fillText(`Total Queue: ${totalQueue}`, 35, 110);
      ctx.fillText(`Serving: ${customers.filter(c => c.status === 'serving').length}`, 35, 135);
    };

    const animate = () => {
      drawCafe();
      animationRef.current = requestAnimationFrame(animate);
    };

    animate();

    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, [customers, c]);

  // Main simulation loop
  useEffect(() => {
    if (!simRunning) return;

    const interval = setInterval(() => {
      const timeIncrement = 0.05 * simSpeed;
      setSimTime(t => t + timeIncrement);

      // Generate new arrivals at entrance (bottom center)
      if (Math.random() < (lambda / 3600) * timeIncrement * 50) {
        setNextCustomerId(id => {
          const width = window.innerWidth;
          const height = window.innerHeight;
          const columnWidth = Math.min(180, (width - 100) / c);
          const startX = (width - (c * columnWidth)) / 2;
          
          // Assign to shortest queue
          const queueCounts = {};
          for (let i = 0; i < c; i++) {
            queueCounts[i] = customers.filter(c => c.queueColumn === i && c.status === 'waiting').length;
          }
          const shortestQueue = Object.keys(queueCounts).reduce((a, b) => 
            queueCounts[a] <= queueCounts[b] ? a : b
          );
          
          const targetColumn = parseInt(shortestQueue);
          const targetX = startX + targetColumn * columnWidth + columnWidth / 2;
          
          const newCustomer = {
            id: Date.now() + Math.random(),
            displayId: id,
            x: width / 2,
            y: height - 100,
            targetX: targetX,
            targetY: height - 200,
            color: `hsl(${(id * 37) % 360}, 70%, 60%)`,
            arrivalTime: simTime,
            status: 'walking',
            queueColumn: targetColumn,
            queuePosition: queueCounts[shortestQueue],
            serverId: null,
            serviceStartTime: null
          };
          
          setCustomers(prev => [...prev, newCustomer]);
          return id + 1;
        });
      }

      // Update customer positions - ALWAYS move towards target
      setCustomers(prev => {
        const width = window.innerWidth;
        const height = window.innerHeight;
        
        return prev.map(customer => {
          const dx = customer.targetX - customer.x;
          const dy = customer.targetY - customer.y;
          const dist = Math.sqrt(dx * dx + dy * dy);
          
          // Always move if not at target
          if (dist > 2) {
            const speed = (customer.status === 'exiting_down' || customer.status === 'exiting_right') ? 5 : 
                         customer.status === 'serving' ? 4 : 
                         customer.status === 'waiting' ? 2.5 : 3;
            return {
              ...customer,
              x: customer.x + (dx / dist) * speed * simSpeed,
              y: customer.y + (dy / dist) * speed * simSpeed
            };
          } else {
            // Arrived at target
            if (customer.status === 'walking' && dist <= 2) {
              return { ...customer, status: 'waiting', x: customer.targetX, y: customer.targetY };
            }
            if (customer.status === 'exiting_right') {
              // Remove customer when they reach exit
              if (customer.x > width - 100) {
                return null;
              }
            }
          }
          
          return customer;
        }).filter(Boolean);
      });

      // Update queue positions - CONTINUOUS UPDATE for smooth movement up the line
      setCustomers(prev => {
        const width = window.innerWidth;
        const columnWidth = Math.min(180, (width - 100) / c);
        const startX = (width - (c * columnWidth)) / 2;
        const queueStartY = 220;
        const queueSpacing = 70;
        
        // Group by queue column and status
        const queues = {};
        for (let i = 0; i < c; i++) {
          queues[i] = prev.filter(c => c.queueColumn === i && c.status === 'waiting')
                         .sort((a, b) => a.arrivalTime - b.arrivalTime); // Sort by arrival
        }
        
        return prev.map(customer => {
          if (customer.status === 'waiting') {
            const queue = queues[customer.queueColumn];
            const positionInQueue = queue.findIndex(c => c.id === customer.id);
            
            if (positionInQueue !== -1) {
              const targetX = startX + customer.queueColumn * columnWidth + columnWidth / 2;
              const targetY = queueStartY + positionInQueue * queueSpacing;
              
              // Update target immediately so customer moves
              return {
                ...customer,
                targetX: targetX,
                targetY: targetY,
                queuePosition: positionInQueue
              };
            }
          }
          return customer;
        });
      });

      // Assign customers to baristas - only from front of queue
      setCustomers(prev => {
        const width = window.innerWidth;
        const columnWidth = Math.min(180, (width - 100) / c);
        const startX = (width - (c * columnWidth)) / 2;
        const baristaY = 120;
        const queueStartY = 220;
        
        const serving = prev.filter(c => c.status === 'serving');
        
        // Check each barista column
        for (let col = 0; col < c; col++) {
          // Get all waiting customers in this column, sorted by position
          const queueForCol = prev
            .filter(c => c.queueColumn === col && c.status === 'waiting')
            .sort((a, b) => a.queuePosition - b.queuePosition);
          
          const serverBusy = serving.some(c => c.serverId === col);
          
          // Only serve customer if they're at position 0 (front of queue) and close enough
          if (!serverBusy && queueForCol.length > 0) {
            const frontCustomer = queueForCol[0];
            
            // Check if customer is at the front (position 0) and near the barista
            if (frontCustomer.queuePosition === 0) {
              const distanceToBarista = Math.abs(frontCustomer.y - (queueStartY));
              
              // Only serve if customer has reached near the top of queue
              if (distanceToBarista < 10) {
                return prev.map(cust => {
                  if (cust.id === frontCustomer.id) {
                    const serverX = startX + col * columnWidth + columnWidth / 2;
                    return {
                      ...cust,
                      status: 'serving',
                      targetX: serverX,
                      targetY: baristaY + 50,
                      serviceStartTime: simTime,
                      serverId: col
                    };
                  }
                  return cust;
                });
              }
            }
          }
        }
        
        return prev;
      });

      // Complete service and move to exit - organized exit path
      setCustomers(prev => {
        const width = window.innerWidth;
        const height = window.innerHeight;
        const newWaitTimes = [];
        
        return prev.map(customer => {
          if (customer.status === 'serving' && customer.serviceStartTime !== null) {
            const serviceTime = simTime - customer.serviceStartTime;
            const avgServiceTime = 60 / mu;
            
            if (serviceTime > avgServiceTime * (0.5 + Math.random())) {
              const waitTime = customer.serviceStartTime - customer.arrivalTime;
              newWaitTimes.push(waitTime * 60);
              setServedCount(s => s + 1);
              setTotalWaitTime(w => w + waitTime);
              
              if (newWaitTimes.length > 0) {
                setWaitTimeHistory(h => [...h, ...newWaitTimes].slice(-20));
              }
              
              // Organized exit: move down first, then right to exit
              return {
                ...customer,
                status: 'exiting_down',
                targetX: customer.x,
                targetY: height / 2,
                exitStage: 1
              };
            }
          }
          
          // Handle multi-stage exit
          if (customer.status === 'exiting_down') {
            const dy = customer.targetY - customer.y;
            if (Math.abs(dy) < 10) {
              // Reached middle height, now move right
              return {
                ...customer,
                status: 'exiting_right',
                targetX: width - 80,
                targetY: height / 2,
                exitStage: 2
              };
            }
          }
          
          return customer;
        });
      });

    }, 50);

    return () => clearInterval(interval);
  }, [simRunning, lambda, mu, c, simTime, simSpeed, customers]);

  const resetSimulation = () => {
    setSimRunning(false);
    setSimTime(0);
    setCustomers([]);
    setNextCustomerId(1);
    setServedCount(0);
    setTotalWaitTime(0);
    setWaitTimeHistory([]);
  };

  const avgSimWait = servedCount > 0 ? (totalWaitTime / servedCount * 60).toFixed(2) : 0;

  return (
    <div style={{ width: '100vw', height: '100vh', overflow: 'hidden', position: 'relative', fontFamily: 'Georgia, serif' }}>
      <canvas ref={canvasRef} style={{ position: 'absolute', top: 0, left: 0 }} />
      
      <div style={{ 
        position: 'absolute', 
        top: '20px', 
        right: '20px', 
        background: 'rgba(74, 58, 42, 0.95)', 
        padding: '30px', 
        borderRadius: '15px',
        color: '#f4e4c1',
        maxWidth: '450px',
        backdropFilter: 'blur(10px)',
        border: '3px solid #d4a574',
        boxShadow: '0 8px 32px rgba(0,0,0,0.5)',
        maxHeight: '90vh',
        overflowY: 'auto'
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '25px' }}>
          <h2 style={{ margin: 0, fontSize: '32px', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <Coffee size={36} /> Control Panel
          </h2>
          <button 
            onClick={() => setShowControls(!showControls)}
            style={{ 
              background: '#d4a574', 
              border: 'none', 
              borderRadius: '8px', 
              padding: '10px', 
              cursor: 'pointer',
              color: '#2d1810'
            }}
          >
            <Settings size={24} />
          </button>
        </div>

        {/* Wait Time Distribution Chart */}
        <div style={{ 
          background: 'rgba(212, 165, 116, 0.2)', 
          padding: '20px', 
          borderRadius: '10px', 
          marginBottom: '20px',
          border: '2px solid #d4a574'
        }}>
          <h3 style={{ margin: '0 0 15px 0', fontSize: '22px' }}>📊 Wait Time Distribution</h3>
          <div style={{ 
            display: 'flex', 
            alignItems: 'flex-end', 
            height: '120px', 
            gap: '4px',
            background: 'rgba(45, 24, 16, 0.5)',
            padding: '15px',
            borderRadius: '5px',
            border: '1px solid #8b6f47'
          }}>
            {waitTimeHistory.length === 0 ? (
              <div style={{ 
                width: '100%', 
                display: 'flex', 
                alignItems: 'center', 
                justifyContent: 'center',
                fontSize: '16px', 
                opacity: 0.6,
                height: '100%'
              }}>
                Start simulation to see data...
              </div>
            ) : (
              waitTimeHistory.map((time, idx) => {
                const maxTime = Math.max(...waitTimeHistory, 0.1);
                const heightPercent = (time / maxTime) * 100;
                const hue = 120 - (time / maxTime) * 120;
                return (
                  <div
                    key={idx}
                    style={{
                      flex: 1,
                      height: `${heightPercent}%`,
                      background: `hsl(${hue}, 70%, 60%)`,
                      borderRadius: '3px 3px 0 0',
                      minWidth: '12px',
                      transition: 'height 0.3s ease',
                      position: 'relative',
                      boxShadow: '0 2px 4px rgba(0,0,0,0.3)'
                    }}
                    title={`Customer ${servedCount - waitTimeHistory.length + idx + 1}: ${time.toFixed(2)} min`}
                  />
                );
              })
            )}
          </div>
          <div style={{ fontSize: '14px', marginTop: '10px', opacity: 0.9, textAlign: 'center' }}>
            Last {waitTimeHistory.length} customers • <span style={{color: '#4ade80'}}>Green</span>=fast • <span style={{color: '#f87171'}}>Red</span>=slow
          </div>
        </div>

        {showControls && (
          <>
            <div style={{ marginBottom: '25px' }}>
              <label style={{ display: 'block', marginBottom: '10px', fontSize: '18px', fontWeight: 'bold' }}>
                Arrival Rate (λ): {lambda} customers/hour
              </label>
              <input 
                type="range" 
                min="5" 
                max="50" 
                value={lambda} 
                onChange={(e) => setLambda(Number(e.target.value))}
                style={{ width: '100%', height: '8px' }}
              />
            </div>

            <div style={{ marginBottom: '25px' }}>
              <label style={{ display: 'block', marginBottom: '10px', fontSize: '18px', fontWeight: 'bold' }}>
                Service Rate (μ): {mu} orders/hour/barista
              </label>
              <input 
                type="range" 
                min="4" 
                max="20" 
                value={mu} 
                onChange={(e) => setMu(Number(e.target.value))}
                style={{ width: '100%', height: '8px' }}
              />
            </div>

            <div style={{ marginBottom: '25px' }}>
              <label style={{ display: 'block', marginBottom: '10px', fontSize: '18px', fontWeight: 'bold' }}>
                Number of Baristas (c): {c}
              </label>
              <input 
                type="range" 
                min="1" 
                max="6" 
                value={c} 
                onChange={(e) => setC(Number(e.target.value))}
                style={{ width: '100%', height: '8px' }}
              />
            </div>

            <div style={{ marginBottom: '25px' }}>
              <label style={{ display: 'block', marginBottom: '10px', fontSize: '18px', fontWeight: 'bold' }}>
                Simulation Speed: {simSpeed}x
              </label>
              <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                {[0.5, 1, 1.25, 1.5, 2, 3, 5].map(speed => (
                  <button
                    key={speed}
                    onClick={() => setSimSpeed(speed)}
                    style={{
                      padding: '10px 15px',
                      fontSize: '16px',
                      background: simSpeed === speed ? '#5a8c5a' : '#8b6f47',
                      color: 'white',
                      border: simSpeed === speed ? '3px solid #4ade80' : 'none',
                      borderRadius: '8px',
                      cursor: 'pointer',
                      fontWeight: simSpeed === speed ? 'bold' : 'normal',
                      flex: '1 0 auto'
                    }}
                  >
                    {speed}x
                  </button>
                ))}
              </div>
            </div>

            <div style={{ display: 'flex', gap: '15px', marginBottom: '25px' }}>
              <button 
                onClick={() => setSimRunning(!simRunning)}
                style={{ 
                  flex: 1, 
                  padding: '15px', 
                  fontSize: '18px', 
                  background: simRunning ? '#c44536' : '#5a8c5a', 
                  color: 'white', 
                  border: 'none', 
                  borderRadius: '8px', 
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '10px',
                  fontWeight: 'bold'
                }}
              >
                {simRunning ? <><Pause size={20} /> Pause</> : <><Play size={20} /> Start</>}
              </button>
              <button 
                onClick={resetSimulation}
                style={{ 
                  flex: 1, 
                  padding: '15px', 
                  fontSize: '18px', 
                  background: '#8b6f47', 
                  color: 'white', 
                  border: 'none', 
                  borderRadius: '8px', 
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '10px',
                  fontWeight: 'bold'
                }}
              >
                <RotateCcw size={20} /> Reset
              </button>
            </div>
          </>
        )}

        <div style={{ background: 'rgba(212, 165, 116, 0.2)', padding: '20px', borderRadius: '10px', marginBottom: '20px' }}>
          <h3 style={{ margin: '0 0 15px 0', fontSize: '24px', borderBottom: '2px solid #d4a574', paddingBottom: '10px' }}>
            Theoretical Metrics
          </h3>
          <div style={{ fontSize: '18px', lineHeight: '1.8' }}>
            <p><strong>Utilization (ρ):</strong> {metrics.utilization}%</p>
            <p><strong>Prob. of Wait (Erlang C):</strong> {metrics.erlangC}%</p>
            <p><strong>Avg Queue Length (Lq):</strong> {metrics.Lq}</p>
            <p><strong>Avg Wait Time (Wq):</strong> {metrics.Wq} min</p>
            <p><strong>Avg System Size (L):</strong> {metrics.L}</p>
            <p><strong>Avg Time in System (W):</strong> {metrics.W} min</p>
          </div>
        </div>

        <div style={{ background: 'rgba(212, 165, 116, 0.2)', padding: '20px', borderRadius: '10px' }}>
          <h3 style={{ margin: '0 0 15px 0', fontSize: '24px', borderBottom: '2px solid #d4a574', paddingBottom: '10px' }}>
            Live Simulation
          </h3>
          <div style={{ fontSize: '18px', lineHeight: '1.8' }}>
            <p><strong>Sim Time:</strong> {simTime.toFixed(1)}s</p>
            <p><strong>In Queue:</strong> {customers.filter(c => c.status === 'waiting').length}</p>
            <p><strong>Being Served:</strong> {customers.filter(c => c.status === 'serving').length}</p>
            <p><strong>Exiting:</strong> {customers.filter(c => c.status === 'exiting_down' || c.status === 'exiting_right').length}</p>
            <p><strong>Total Served:</strong> {servedCount}</p>
            <p><strong>Avg Wait (Sim):</strong> {avgSimWait} min</p>
          </div>
        </div>

        {rho >= 1 && (
          <div style={{ 
            marginTop: '20px', 
            padding: '15px', 
            background: '#c44536', 
            borderRadius: '8px',
            fontSize: '18px',
            fontWeight: 'bold',
            textAlign: 'center'
          }}>
            ⚠️ System Unstable! (ρ ≥ 1)
          </div>
        )}
      </div>

      <div style={{
        position: 'absolute',
        bottom: '20px',
        left: '20px',
        background: 'rgba(74, 58, 42, 0.95)',
        padding: '20px',
        borderRadius: '10px',
        color: '#f4e4c1',
        fontSize: '16px',
        maxWidth: '400px',
        border: '2px solid #d4a574'
      }}>
        <h3 style={{ margin: '0 0 10px 0', fontSize: '22px' }}>M/M/{c} Queue System</h3>
        <p style={{ margin: '5px 0', lineHeight: '1.6' }}>
          <strong>Kendall Notation:</strong> M/M/{c}<br/>
          <strong>Traffic Intensity (a):</strong> {trafficIntensity.toFixed(2)}<br/>
          <strong>Formula:</strong> Lq = (ρ^c × ρ × P₀) / (c! × (1-ρ)²)
        </p>
      </div>
    </div>
  );
};

export default CoffeeShopQueueAnalyzer;