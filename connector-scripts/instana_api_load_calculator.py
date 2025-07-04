import os
import json
import requests
from prettytable import PrettyTable
from collections import defaultdict
from datetime import datetime
from copy import deepcopy
from math import ceil

# ---------------------- Configurable Inputs ----------------------
instana_base_url = "<BaseURL>"
access_token = "<AccessToken>"
metrics_config_json = '''
[
    {"aceMessageFlow":["msgWithErrors","processingMsgErrors","backouts","mqErrors","timeOutsWaitingForRepliesToAggregateMsgs","totalCpuTime","cpuTimeWaitingForInputMsgs","commits","elapsedTimeWaitingForInputMsgs","totalElapsedTime","timesMaxNumberOfThreadsReached","totalInputMsgs"]},
    {"application":["erroneousCalls","errors","http.4xx","http.5xx","latency"]},
    {"awsElb":["elb_5XX_count","rejected_connection_count"]},
    {"db2Database":["lockWaits","workloadstats.totalRequestTime","workloadstats.totalWaitTime","workloadstats.lockTimeouts"]},
    {"endpoint":["erroneousCalls","latency","errors","http.4xx","http.5xx"]},
    {"host":["tcp.resets","cpu.wait","cpu.sys","cpu.user","tcp.errors","ctxt","cpu.used","tcp.retrans"]},
    {"ibmMqChannel":["messagesAvailable"]},
    {"ibmMqQueue":["queueDepth","messagesIn","messagesOut"]},
    {"ibmMqQueueManager":["messagesIn","messagesOut"]},
    {"ibmMqTopic":["messagesCount"]},
    {"jvmRuntimePlatform":["threads.blocked","suspension.time"]},
    {"kubernetesNamespace":["used_limits_memory","used_limits_cpu"]},
    {"kubernetesNode":["required_mem_percentage","required_cpu_percentage"]},
    {"mariaDbDatabase":["status.SLOW_QUERIES"]},
    {"mongoDb":["repl.network_bytes","repl.preload_docs_total_ms","repl.apply_bathes_total_ms"]},
    {"mongoDbReplicaSet":["repl.preload_docs_total_ms","connections"]},
    {"msSqlDatabase":["waitstats.PAGEIOLATCH_SH.wait_time_ms","generalstats._total.user_connections","perfcounters.locks._total.number_of_deadlocks_sec","waitstats.ASYNC_NETWORK_IO.wait_time_ms","iostats._total.num_of_bytes_read","waitstats.PAGEIOLATCH_EX.wait_time_ms","waitstats.CXPACKET.wait_time_ms","waitstats.WRITELOG.wait_time_ms","iostats._total.num_of_bytes_written"]},
    {"mySqlDatabase":["status.SLOW_QUERIES","status.KEY_WRITE_REQUESTS","status.COM_SHOW_ERRORS","status.THREADS_CONNECTED","status.ABORTED_CONNECTS"]},
    {"service":["erroneousCalls","latency","errors","http.4xx","http.5xx"]}
]
'''
polling_interval_minutes = 5
# ------------------------------------------------------------------

# Plugins to exclude from search zone calculation
EXCLUDED_PLUGINS = {"application", "endpoint", "service"}
BATCH_SIZE = 30
HEADERS = {
    "Authorization": f"apiToken {access_token}",
    "Content-Type": "application/json"
}

metrics_config = json.loads(metrics_config_json)

def red(text):
    return f"\033[91m{text}\033[0m" if os.isatty(1) else text

def get_node_array():
    url = f"{instana_base_url}/api/infrastructure-monitoring/topology?includeData=false"
    response = requests.get(url, headers=HEADERS)
    response.raise_for_status()
    return response.json().get("nodes", [])

def get_search_zone_limit():
    for entry in metrics_config:
        for plugin, metrics in entry.items():
            if plugin not in EXCLUDED_PLUGINS:
                selected_metrics = metrics[:min(5, len(metrics))]
                url = f"{instana_base_url}/api/infrastructure-monitoring/metrics"
                payload = {
                    "plugin": plugin,
                    "metrics": selected_metrics,
                    "snapshotIds": [],
                    "timeFrame": polling_interval_minutes * 60 * 1000  # milliseconds
                }
                response = requests.post(url, headers=HEADERS, json=payload)
                return int(response.headers.get('x-ratelimit-limit', 0))
    print("No applicable plugin found to test search zone limit.")
    return 0

def build_plugin_snapshotid_map(node_array, metric_config, excluded_plugins=None):
    plugin_map = defaultdict(list)
    for entry in metric_config:
        for plugin_name in entry:
            if plugin_name not in EXCLUDED_PLUGINS:
                for node in node_array:
                    if node.get("plugin") == plugin_name:
                        snapshot_id = node.get("id")
                        if snapshot_id:
                            plugin_map[plugin_name].append(snapshot_id)
    return plugin_map

def estimate_hourly_requests(num_snapshots, num_metrics):
        return ceil(num_snapshots / BATCH_SIZE) * ceil(num_metrics / 5) * ceil(60 / polling_interval_minutes)

def generate_integrations_group(plugin_snapshot_map, metrics_config, max_requests):
    plugin_chunks = []
    for entry in metrics_config:
        for plugin, metrics in entry.items():
            if plugin not in plugin_snapshot_map:
                continue
            snapshots = plugin_snapshot_map[plugin]
            for i in range(0, len(metrics), 5):
                chunk = metrics[i:i+5]
                req_count = estimate_hourly_requests(len(snapshots), len(chunk))
                plugin_chunks.append({
                    "plugin": plugin,
                    "snapshots": snapshots,
                    "metrics": chunk,
                    "requests": req_count
                })
    plugin_chunks.sort(key=lambda x: x["requests"], reverse=True)

    bins = []
    bin_usage = []
    for chunk in plugin_chunks:
        placed = False
        for i, total in enumerate(bin_usage):
            if total + chunk["requests"] <= max_requests:
                bins[i].append(chunk)
                bin_usage[i] += chunk["requests"]
                placed = True
                break
        if not placed:
            bins.append([chunk])
            bin_usage.append(chunk["requests"])

    integration_groups = []
    for bin_chunks in bins:
        integration = defaultdict(lambda: {"metrics": [], "snapshots": []})
        for chunk in bin_chunks:
            plugin = chunk["plugin"]
            integration[plugin]["metrics"].extend(chunk["metrics"])
            integration[plugin]["snapshots"] = chunk["snapshots"]
        integration_groups.append(integration)
    return integration_groups

def format_as_multiline(metrics):
    if isinstance(metrics, list):
        lines = ["["] + [f"  {m}" for m in metrics] + ["]"]
        return "\n".join(lines)
    return str(metrics)

if __name__ == "__main__":
    try:
        nodes = get_node_array()

        print("Extracting snapshot IDs by plugin...")
        plugin_snapshot_map = build_plugin_snapshotid_map(nodes, metrics_config)

        print(f"Total nodes found: {len(nodes)}")
        total_requests = 0
        plugin_request_map = {}

        table = PrettyTable()
        table.field_names = ["Plugin Name", "No. of Hosts", "Metrics Count", "Requests in Poll Interval"]
        for plugin, snapshotIds in plugin_snapshot_map.items():
            metrics_count = 0
            for entry in metrics_config:
                if plugin in entry:
                    metrics_count = len(entry[plugin])
                    break
            snapshotIdCount = len(snapshotIds)
            hostBatch = ceil(snapshotIdCount / BATCH_SIZE)
            metricBatch = ceil(metrics_count / 5) if metrics_count else 0
            requestCnt = hostBatch * metricBatch
            plugin_request_map[plugin] = requestCnt
            total_requests += requestCnt
            table.add_row([plugin, snapshotIdCount, metrics_count, requestCnt])
        print(table)

        total_hourly_requests = total_requests*ceil(60/polling_interval_minutes)
        print(f"Total search zone requests per {polling_interval_minutes}-minute interval: {total_requests}")
        print(f"Total search zone requests per hour: {total_hourly_requests}")
        search_zone_limit = get_search_zone_limit()
        if search_zone_limit and total_hourly_requests > search_zone_limit:
            print(red(f"\n  WARNING: Request count {total_hourly_requests} exceeds search zone limit {search_zone_limit}!"))
            estimated_integrations = ceil(total_hourly_requests / search_zone_limit)
            print(f"Estimated Number of Instana Connector Integrations: {estimated_integrations}")

            print("\n Suggested Plugin Grouping for Balanced Integrations")
            
            integration_groups = generate_integrations_group(
                plugin_snapshot_map,
                metrics_config,
                search_zone_limit
            )

            for idx, group in enumerate(integration_groups, 1):
                print(f"\nIntegration {idx}:")
                table = PrettyTable()
                table.field_names = ["Plugin Name", "Requests Count", "Metrics Group"]
                total_integration_requests = 0
                for plugin, data in group.items():
                    snapshot_count = len(data["snapshots"])
                    metric_count = len(data["metrics"])
                    hourly_requests = estimate_hourly_requests(snapshot_count, metric_count)
                    total_integration_requests += hourly_requests
                    metrics = format_as_multiline(data["metrics"])
                    table.add_row([plugin, hourly_requests, metrics])

                print(table)
                print(f"  Total Requests: {total_integration_requests}")
                if (total_integration_requests > search_zone_limit):
                    print(red(f"\n  WARNING: Due to a large host count, total hourly requests exceed the search zone limit ({search_zone_limit}). Please set a host filter or increase the search zone limit to resolve this."))
                
            print(f"\nReport generated at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
    except Exception as e:
        print(f"Error: {e}")
