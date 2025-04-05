from flask import Flask, request, jsonify
import pandas as pd
import joblib
from datetime import datetime, timedelta
import random  # For simulating data if models fail

app = Flask(__name__)

# --- 1. Load Models (Adapt for multi-output or separate models) ---
try:
    time_model = joblib.load('travel_time_model.joblib')
    cost_model = joblib.load('travel_cost_model.joblib')
    weather_model = joblib.load('weather_model.joblib')  # Example
    congestion_model = joblib.load('congestion_model.joblib')  # Example
    training_features = joblib.load('training_features.joblib')
except FileNotFoundError as e:
    print(f"Error loading model files: {e}")
    exit(1)


# --- 2. Data Preparation ---
def prepare_data_for_prediction(data, for_time_cost=True):
    """
    Prepares input data for the ML models.
    Adapt for different model inputs if needed.
    """
    df = pd.DataFrame([data])
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    df['hour'] = df['timestamp'].dt.hour
    df['day_of_week'] = df['timestamp'].dt.dayofweek
    df['month'] = df['timestamp'].dt.month
    df = pd.get_dummies(df, columns=['from_address'], drop_first=True)
    for feature in training_features:
        if feature not in df.columns:
            df[feature] = 0
    df = df.fillna(0)
    df = df[training_features]
    if for_time_cost:
        df = df.drop(columns=['predicted_weather', 'predicted_congestion_level'], errors='ignore') # If predicting these separately
    return df


# --- 3. Simulated Data Fetching (Now Model Predictions) ---
def fetch_predicted_data(from_address, to_address, departure_timestamp):
    """
    Predicts weather, congestion, etc., using ML models.
    Adapt based on your model structure.
    """

    # --- Simulate predictions (REPLACE with actual model calls) ---
    # Example: Using separate models
    weather_options = ["Sunny", "Rain", "Cloudy"]
    # weather = weather_model.predict(prepare_data_for_prediction(
    #     {'timestamp': departure_timestamp, 'from_address': from_address, 'to_address': to_address}, for_time_cost=False))[0]
    weather = random.choice(weather_options) # Placeholder

    # congestion_level = congestion_model.predict(prepare_data_for_prediction(
    #     {'timestamp': departure_timestamp, 'from_address': from_address, 'to_address': to_address}, for_time_cost=False))[0]
    congestion_level = random.randint(1, 5)  # Placeholder

    toll_cost = random.uniform(0, 10) if random.random() < 0.5 else 0.0
    carpool_available = random.choice(['yes', 'no'])
    accidents_nearby = random.randint(0, 2)
    construction_nearby = random.randint(0, 1)
    road_closed = random.choice(['yes', 'no']) if random.random() < 0.1 else 'no'

    return {
        'weather': weather,
        'congestion_level': congestion_level,
        'toll_cost': toll_cost,
        'carpool_available': carpool_available,
        'accidents_nearby': accidents_nearby,
        'construction_nearby': construction_nearby,
        'road_closed': road_closed
    }


# --- 4. API Endpoint ---
@app.route('/recommend-team-travel', methods=['POST'])
def recommend_team_travel():
    try:
        request_data = request.get_json()
        start_time_window = request_data.get('startTimeWindow')
        end_time_window = request_data.get('endTimeWindow')
        from_addresses = request_data.get('fromAddresses')
        to_address = request_data.get('toAddress')
        infrastructure_cost_factor = request_data.get('infrastructureCostFactor')

        # ... (Input validation as before)

        possible_departure_times = []
        current_time = datetime.now()
        departure_interval_minutes = 15
        departure_time = start_time
        while departure_time <= end_time and departure_time > current_time:
            possible_departure_times.append(departure_time.strftime('%Y-%m-%d %H:%M:%S'))
            departure_time += timedelta(minutes=departure_interval_minutes)

        best_departure_time = None
        min_total_team_cost = float('inf')
        max_team_travel_time = 0.0

        for departure_time_str in possible_departure_times:
            departure_timestamp = datetime.strptime(departure_time_str, '%Y-%m-%d %H:%M:%S')
            total_team_cost = 0.0
            max_team_travel_time = 0.0

            for from_address in from_addresses:
                # Use model predictions instead of API calls
                predicted_data = fetch_predicted_data(from_address, to_address, departure_timestamp)

                current_conditions = {
                    'timestamp': departure_timestamp,
                    'from_address': from_address,
                    'to_address': to_address,
                    'congestion_level': predicted_data['congestion_level'],
                    'weather': predicted_data['weather'],
                    'toll_cost': predicted_data['toll_cost'],
                    'carpool_available': predicted_data['carpool_available'],
                    'accidents_nearby': predicted_data['accidents_nearby'],
                    'construction_nearby': predicted_data['construction_nearby'],
                    'road_closed': predicted_data['road_closed'],
                    'team_size': len(from_addresses)
                }

                time_input = prepare_data_for_prediction(current_conditions, for_time_cost=True)
                cost_input = prepare_data_for_prediction(current_conditions, for_time_cost=True) # Or separate data prep

                predicted_time = time_model.predict(time_input)[0] # Access the first element of the prediction
                predicted_cost = cost_model.predict(cost_input)[0]

                if predicted_time is not None and predicted_cost is not None:
                    total_team_cost += (predicted_time / 3600) * infrastructure_cost_factor + predicted_cost
                    max_team_travel_time = max(max_team_travel_time, predicted_time)

            total_team_cost += (max_team_travel_time / 3600) * 0.1

            if best_departure_time is None or total_team_cost < min_total_team_cost:
                best_departure_time = departure_timestamp
                min_total_team_cost = total_team_cost

        # ... (Response formatting and error handling as before)

    except Exception as e:
        print(f"Error processing request: {e}")
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    app.run(debug=True, port=5000)

