# MotionStudies receiving station

This read-only example bridges MotionStudies' existing `/api/feeds/v1/status` observer endpoint to Prometheus metrics. It uses Python's standard library, binds only to `127.0.0.1`, and does not modify the observer, recorder, or feeds. It is an example to run alongside a Prometheus server, not an automatically installed service.

```text
MotionStudies observer → this exporter → Prometheus → Hello Mini Communications
```

1. Supply the observer's existing `FEED_READ_TOKEN` through the exporter's environment. If protected by Cloudflare Access, also supply `CF_ACCESS_CLIENT_ID` and `CF_ACCESS_CLIENT_SECRET`. Keep these in your usual secret manager or service configuration, out of command arguments and Git.
2. Run the exporter with Python 3.10 or later, replacing the example hostname with the observer's actual final HTTPS URL:

   ```sh
   python3 examples/communications/motionstudies_exporter.py \
     --url https://observer.example/api/feeds/v1/status
   ```

3. Merge the scrape job in [prometheus.yml](prometheus.yml) into your existing Prometheus configuration, or start a local Prometheus with this file and a loopback listener:

   ```sh
   prometheus --config.file=examples/communications/prometheus.yml \
     --web.listen-address=127.0.0.1:9090
   ```

4. In Hello Mini, open **Communications → Station Setup**, choose **Motion Studies preset**, enter `http://127.0.0.1:9090`, and enable connection. If Prometheus runs elsewhere, expose its query API through your usual authenticated HTTPS service; the app accepts an optional read-only bearer token.

The exporter and Prometheus must share the same host network for the loopback example. A container's loopback is a different network. Do not expose this example's unauthenticated metrics listener publicly. Hello Mini connects to the metrics backend; the MotionStudies read token belongs only to the exporter.

## Meaning of the readings

The preset contains the observer's overall assessment, five feed channels, and recorder heartbeat age. These names match the current MotionStudies registry; edit queries if your registry differs. With multiple exporter instances, filter all preset queries by the appropriate `job` or `instance` label so each returns exactly one series.

- `motionstudies_observer_state` is the observer's read-time assessment, subject to the freshness checks below.
- `motionstudies_feed_state{feed="…"}` describes each feed in the **last completed check**. The adapter does not duplicate the observer's per-stage business rules. Check the overall assessment as well: it can become degraded between completed checks.
- `motionstudies_observer_check_timestamp_seconds` preserves the original completed-check timestamp; scraping never renews it.
- `motionstudies_producer_timestamp_seconds` preserves the producer heartbeat timestamp.
- `motionstudies_exporter_up` indicates whether the upstream response decoded; it is not proof that feeds are healthy.

State codes are `0 healthy`, `1 waiting`, `2 degraded`, `3 paused`, `4 unknown`. Setup-required is unknown. The adapter requires assessment, check, and producer timestamps no older than 180 seconds and no more than 30 seconds in the future, current producer telemetry, and no failed check/source error. Otherwise feed and observer readings become unknown. These conservative freshness limits suit this preset; adapt them deliberately for another producer cadence.

The observer deliberately returns HTTP 503 for unhealthy assessments; its valid body is still decoded. Authentication/network/parse failures emit exporter-up `0` and observer-state `4`, with no reused feed values. Responses are limited to 2 MB; HTTP redirects are refused. The response is cached for at most 30 seconds and re-aged on each scrape. Logs and metric labels exclude upstream error text, payloads, and credentials.

Requests identify themselves as `HelloMini-MotionStudiesReceiver/0.5.0`. Cloudflare can reject Python's generic default user agent with error 1010 before checking the observer credentials; this explicit application identity avoids that rejection without impersonating a browser or changing the site's security policy.

Run the adapter tests:

```sh
python3 -m unittest discover -s examples/communications -p 'test_*.py'
```

For a different service, export your own metrics directly or through OpenTelemetry and configure the station's generic queries. This adapter's metric names and state codes are application conventions, not additions to the OpenTelemetry standard.
