-- M/M/c Queue Analyzer Database Schema
-- Stores queue simulation results and analytical metrics

CREATE DATABASE IF NOT EXISTS queue_analyzer;
USE queue_analyzer;

-- Table to store queue configurations
CREATE TABLE queue_configurations (
    config_id INT PRIMARY KEY AUTO_INCREMENT,
    lambda_rate DECIMAL(10, 4) NOT NULL COMMENT 'Arrival rate (customers/hour)',
    mu_rate DECIMAL(10, 4) NOT NULL COMMENT 'Service rate (orders/hour/server)',
    c_servers INT NOT NULL COMMENT 'Number of servers',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    description VARCHAR(255),
    INDEX idx_rates (lambda_rate, mu_rate, c_servers)
);

-- Table to store theoretical metrics
CREATE TABLE theoretical_metrics (
    metric_id INT PRIMARY KEY AUTO_INCREMENT,
    config_id INT NOT NULL,
    rho DECIMAL(10, 6) NOT NULL COMMENT 'System utilization',
    traffic_intensity DECIMAL(10, 6) NOT NULL COMMENT 'Lambda/Mu',
    p0 DECIMAL(10, 8) NOT NULL COMMENT 'Probability of empty system',
    erlang_c DECIMAL(10, 8) NOT NULL COMMENT 'Probability of waiting',
    lq DECIMAL(10, 4) NOT NULL COMMENT 'Average queue length',
    wq DECIMAL(10, 4) NOT NULL COMMENT 'Average wait time (minutes)',
    l DECIMAL(10, 4) NOT NULL COMMENT 'Average customers in system',
    w DECIMAL(10, 4) NOT NULL COMMENT 'Average time in system (minutes)',
    utilization_percent DECIMAL(10, 4) NOT NULL,
    is_stable BOOLEAN NOT NULL,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (config_id) REFERENCES queue_configurations(config_id) ON DELETE CASCADE
);

-- Table to store simulation runs
CREATE TABLE simulation_runs (
    sim_id INT PRIMARY KEY AUTO_INCREMENT,
    config_id INT NOT NULL,
    duration_hours DECIMAL(10, 2) NOT NULL,
    total_arrivals INT NOT NULL,
    total_served INT NOT NULL,
    avg_wait_time DECIMAL(10, 4) NOT NULL COMMENT 'Average wait time (minutes)',
    max_wait_time DECIMAL(10, 4) NOT NULL COMMENT 'Maximum wait time (minutes)',
    avg_queue_length DECIMAL(10, 4),
    max_queue_length INT,
    simulation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    random_seed INT,
    FOREIGN KEY (config_id) REFERENCES queue_configurations(config_id) ON DELETE CASCADE,
    INDEX idx_config_date (config_id, simulation_date)
);

-- Table to store individual customer records from simulations
CREATE TABLE customer_records (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    sim_id INT NOT NULL,
    arrival_time DECIMAL(10, 4) NOT NULL COMMENT 'Time of arrival (hours)',
    service_start_time DECIMAL(10, 4) NOT NULL COMMENT 'Time service began (hours)',
    service_end_time DECIMAL(10, 4) NOT NULL COMMENT 'Time service ended (hours)',
    wait_time DECIMAL(10, 4) NOT NULL COMMENT 'Wait time (hours)',
    service_time DECIMAL(10, 4) NOT NULL COMMENT 'Service time (hours)',
    server_id INT NOT NULL COMMENT 'Which server handled the customer',
    FOREIGN KEY (sim_id) REFERENCES simulation_runs(sim_id) ON DELETE CASCADE,
    INDEX idx_sim_arrival (sim_id, arrival_time)
);

-- Table to store state probabilities
CREATE TABLE state_probabilities (
    prob_id INT PRIMARY KEY AUTO_INCREMENT,
    config_id INT NOT NULL,
    state_n INT NOT NULL COMMENT 'Number of customers in system',
    probability DECIMAL(12, 10) NOT NULL,
    customers_in_queue INT NOT NULL,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (config_id) REFERENCES queue_configurations(config_id) ON DELETE CASCADE,
    INDEX idx_config_state (config_id, state_n)
);

-- Table to store birth-death process transitions
CREATE TABLE birth_death_transitions (
    transition_id INT PRIMARY KEY AUTO_INCREMENT,
    config_id INT NOT NULL,
    from_state INT NOT NULL,
    to_state INT NOT NULL,
    transition_rate DECIMAL(10, 4) NOT NULL,
    transition_type ENUM('arrival', 'departure') NOT NULL,
    FOREIGN KEY (config_id) REFERENCES queue_configurations(config_id) ON DELETE CASCADE,
    INDEX idx_config_states (config_id, from_state, to_state)
);

-- View to compare theoretical vs simulated metrics
CREATE VIEW metrics_comparison AS
SELECT 
    qc.config_id,
    qc.lambda_rate,
    qc.mu_rate,
    qc.c_servers,
    tm.wq AS theoretical_wait_time,
    AVG(sr.avg_wait_time) AS avg_simulated_wait_time,
    tm.lq AS theoretical_queue_length,
    AVG(sr.avg_queue_length) AS avg_simulated_queue_length,
    tm.utilization_percent,
    COUNT(sr.sim_id) AS num_simulations
FROM queue_configurations qc
JOIN theoretical_metrics tm ON qc.config_id = tm.config_id
LEFT JOIN simulation_runs sr ON qc.config_id = sr.config_id
GROUP BY qc.config_id, tm.metric_id;

-- View to analyze system performance by utilization level
CREATE VIEW performance_by_utilization AS
SELECT 
    FLOOR(tm.utilization_percent / 10) * 10 AS utilization_bucket,
    COUNT(*) AS num_configs,
    AVG(tm.wq) AS avg_wait_time,
    AVG(tm.lq) AS avg_queue_length,
    AVG(tm.erlang_c) AS avg_prob_waiting,
    MIN(tm.wq) AS min_wait_time,
    MAX(tm.wq) AS max_wait_time
FROM theoretical_metrics tm
WHERE tm.is_stable = TRUE
GROUP BY utilization_bucket
ORDER BY utilization_bucket;

-- Stored procedure to insert configuration and calculate metrics
DELIMITER //
CREATE PROCEDURE insert_queue_analysis(
    IN p_lambda DECIMAL(10, 4),
    IN p_mu DECIMAL(10, 4),
    IN p_c INT,
    IN p_description VARCHAR(255),
    OUT p_config_id INT
)
BEGIN
    DECLARE v_rho DECIMAL(10, 6);
    DECLARE v_traffic DECIMAL(10, 6);
    DECLARE v_stable BOOLEAN;
    
    -- Insert configuration
    INSERT INTO queue_configurations (lambda_rate, mu_rate, c_servers, description)
    VALUES (p_lambda, p_mu, p_c, p_description);
    
    SET p_config_id = LAST_INSERT_ID();
    
    -- Calculate basic metrics
    SET v_traffic = p_lambda / p_mu;
    SET v_rho = p_lambda / (p_c * p_mu);
    SET v_stable = (v_rho < 1.0);
    
    -- Note: Full Erlang C calculation would require more complex SQL
    -- This is a placeholder for the structure
    INSERT INTO theoretical_metrics (
        config_id, rho, traffic_intensity, p0, erlang_c, 
        lq, wq, l, w, utilization_percent, is_stable
    )
    VALUES (
        p_config_id, v_rho, v_traffic, 0, 0,
        0, 0, 0, 0, v_rho * 100, v_stable
    );
END //
DELIMITER ;

-- Stored procedure to record simulation results
DELIMITER //
CREATE PROCEDURE insert_simulation_result(
    IN p_config_id INT,
    IN p_duration DECIMAL(10, 2),
    IN p_arrivals INT,
    IN p_served INT,
    IN p_avg_wait DECIMAL(10, 4),
    IN p_max_wait DECIMAL(10, 4),
    IN p_avg_queue DECIMAL(10, 4),
    IN p_max_queue INT,
    IN p_seed INT
)
BEGIN
    INSERT INTO simulation_runs (
        config_id, duration_hours, total_arrivals, total_served,
        avg_wait_time, max_wait_time, avg_queue_length, max_queue_length, random_seed
    )
    VALUES (
        p_config_id, p_duration, p_arrivals, p_served,
        p_avg_wait, p_max_wait, p_avg_queue, p_max_queue, p_seed
    );
END //
DELIMITER ;

-- Sample data insertion
INSERT INTO queue_configurations (lambda_rate, mu_rate, c_servers, description)
VALUES 
    (20.0, 8.0, 3, 'Standard coffee shop - morning rush'),
    (15.0, 10.0, 2, 'Low traffic - afternoon'),
    (30.0, 8.0, 4, 'High traffic - peak hours'),
    (10.0, 5.0, 3, 'Slow service - understaffed'),
    (25.0, 10.0, 3, 'Fast service - experienced baristas');

-- Sample metrics (simplified - real Erlang C calculations would be done in application)
INSERT INTO theoretical_metrics (config_id, rho, traffic_intensity, p0, erlang_c, lq, wq, l, w, utilization_percent, is_stable)
VALUES
    (1, 0.833, 2.50, 0.045, 0.354, 1.47, 4.42, 4.14, 12.42, 83.3, TRUE),
    (2, 0.750, 1.50, 0.118, 0.237, 0.53, 2.11, 2.03, 8.11, 75.0, TRUE),
    (3, 0.938, 3.75, 0.018, 0.567, 4.53, 9.06, 7.78, 15.56, 93.8, TRUE),
    (4, 0.667, 2.00, 0.091, 0.286, 0.57, 3.43, 2.57, 15.43, 66.7, TRUE),
    (5, 0.833, 2.50, 0.045, 0.354, 1.47, 3.53, 4.14, 9.93, 83.3, TRUE);

-- Sample simulation results
INSERT INTO simulation_runs (config_id, duration_hours, total_arrivals, total_served, avg_wait_time, max_wait_time, avg_queue_length, max_queue_length, random_seed)
VALUES
    (1, 100, 2003, 2003, 4.38, 28.5, 1.52, 8, 12345),
    (1, 100, 1998, 1998, 4.51, 31.2, 1.48, 7, 67890),
    (2, 100, 1502, 1502, 2.18, 18.3, 0.51, 5, 11111),
    (3, 100, 2995, 2995, 9.12, 45.7, 4.62, 12, 22222),
    (5, 100, 2501, 2501, 3.47, 22.1, 1.44, 7, 33333);

-- Query examples

-- 1. Find optimal server count for given arrival/service rates
SELECT 
    c_servers,
    utilization_percent,
    wq AS avg_wait_minutes,
    lq AS avg_queue_length,
    erlang_c AS prob_waiting
FROM queue_configurations qc
JOIN theoretical_metrics tm ON qc.config_id = tm.config_id
WHERE lambda_rate = 20.0 AND mu_rate = 8.0 AND is_stable = TRUE
ORDER BY c_servers;

-- 2. Compare theoretical vs simulated wait times
SELECT * FROM metrics_comparison WHERE config_id = 1;

-- 3. Find configurations with high probability of waiting
SELECT 
    qc.lambda_rate,
    qc.mu_rate,
    qc.c_servers,
    tm.erlang_c * 100 AS prob_waiting_percent,
    tm.wq AS avg_wait_minutes
FROM queue_configurations qc
JOIN theoretical_metrics tm ON qc.config_id = tm.config_id
WHERE tm.erlang_c > 0.5 AND tm.is_stable = TRUE
ORDER BY tm.erlang_c DESC;

-- 4. Analyze impact of adding servers
SELECT 
    lambda_rate,
    mu_rate,
    c_servers,
    wq AS wait_time,
    wq - LAG(wq) OVER (PARTITION BY lambda_rate, mu_rate ORDER BY c_servers) AS wait_reduction
FROM queue_configurations qc
JOIN theoretical_metrics tm ON qc.config_id = tm.config_id
WHERE is_stable = TRUE
ORDER BY lambda_rate, mu_rate, c_servers;