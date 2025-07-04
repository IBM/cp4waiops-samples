# Instana Plugin Request Analyzer

This tool estimates and optimizes the number of hourly **search zone requests** made by Instana plugin metrics. If the request count exceeds Instana's configured rate limit, it provides a **grouped integration plan** using an efficient **bin-packing algorithm** to stay within the limit.

---

## Prerequisites

- Python 3.7 or higher
- Required Python packages:
  - `requests`
  - `prettytable`

Install dependencies using:

```bash
pip install requests prettytable
```

## How It Works

1. Fetch Node Data: Retrieves the full plugin-snapshot mapping from Instana’s topology API.

2. Estimate Requests: Computes estimated requests per plugin using the number of hosts and metrics.

3. Validate Against Limit: Compares total hourly request load with the rate limit configured in Instana.

4. Optimize Integrations: If the load exceeds the limit, splits the plugins into multiple integrations using a First-Fit Decreasing (FFD) algorithm to balance them efficiently.

5. Output Report: Presents results in well-structured tables with per-plugin stats and grouping.


## Configuration

Update the following fields in the script:

```python
instana_base_url = "<BaseURL>"                  # Example: "https://instana.yourcompany.com"
access_token = "<AccessToken>"                  # Instana API Token
metrics_config_json = "<Metric Configuration>"  # 
polling_interval_minutes = 5                    # Polling interval in minutes (default: 5)
```

## Usage

Run the script using:
```bash
python3 instana_api_load_calculator.py
```
The script will:
- Print estimated request load per plugin
- Warn if the search zone request limit is exceeded
- Suggest an optimal grouping of plugins into integrations

## Notes
- Metrics are grouped in chunks of 5 per request, as per Instana's constraints.
- Hosts are grouped in batches of 30 per request.
- The rate limit is auto-discovered from the Instana API.
- Plugins like application, endpoint, and service are excluded from this analysis as they doesn't fall under search zone limit.