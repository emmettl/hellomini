# Communications

Communications is available from 0.5.0. It turns a Prometheus-compatible metrics server into a tiny receiving station: a switchboard of channels, status lamps, a paper strip chart, and a station log. It works with any matching metrics source; MotionStudies is an optional preset.

## Connect a station

1. Launch **Communications** and choose **Station Setup**.
2. Enter the metrics server's **base URL**, including any subpath. The app appends `/api/v1/query` and `/api/v1/query_range`. HTTPS is required, except for local servers such as `http://127.0.0.1:9090`.
3. Add up to eight channels. Each PromQL query must return exactly one numeric series or scalar. Filter labels or aggregate explicitly; multiple matches are treated as unknown.
4. Choose a number, seconds, or state-code reading. Numeric thresholds are optional; “below threshold is bad” reverses the comparison. Equality is healthy. Without a threshold, healthy means a current finite sample, not an assertion that the underlying service is healthy.
5. Set a freshness limit (30–86400 seconds). Where available, add an **evidence timestamp query** returning the source's original observation time as Unix seconds. This prevents repeatedly scraping an old observation from making it appear healthy.
6. Enable **Connect when saved and resume on launch**, then save. Otherwise, use Connect when ready.

For example, a channel querying `up{job="recorder"}` with threshold `1` and “below threshold is bad” reports scrape availability. A query such as `time() - last_success_timestamp_seconds` can report time since successful work, if your source exports that metric. Metric names and thresholds are yours to configure.

A bearer token is optional and stays in macOS Keychain, bound to the exact server URL. Blank keeps the saved token; **Forget token for this server** removes it. Use a server offering read-only query access. URL credentials, query strings, fragments, and redirects are refused. There is no browser login, custom-header editor, or client-certificate configuration in this first version.

## Read the instruments

- **Switchboard:** Select a callsign to see its query, sample time, original evidence time, last receipt time, and reason for its state. State codes are `0 healthy`, `1 waiting`, `2 degraded`, `3 paused`, `4 unknown`; other values are unknown. This is a station profile convention, not an OpenTelemetry semantic convention.
- **Chart:** Select a channel for the previous hour at one-minute resolution. Missing/non-finite samples leave gaps. State codes use a stepped trace. The perforated paper is decorative; its movement does not represent new measurements.
- **Log:** Up to 200 initial observations and state changes from this session. Repeated readings do not create entries. Reconfiguring, disconnecting, or entering simulation clears this local log; retained metrics history belongs to the server.
- **Test Lamps:** Lights the indicators for three seconds without changing readings, sending requests, or sounding an alarm.
- **Station → Run Simulation:** Shows clearly labelled training data without network requests or sounds. **End Simulation** returns to the saved station, resuming its connection if it was enabled. Simulated data never overwrites the station profile.

Connected stations poll every 30 seconds while Hello Mini runs, including when this accessory is closed. At most three channels are queried concurrently. Disconnect stops future polling; quitting stops all app polling. A failed request, ambiguous or partial response, stale sample, missing required evidence, non-finite value, or timestamp more than 30 seconds in the future produces **Signal lost**, never a retained green light. Requests and response sizes are bounded. The server remains responsible for collection and retention while the app is off.

**Sound on loss and recovery** is opt-in in Station Setup. It also respects **Control Panel → Playfulness → System sounds**, the Extra silliness switch, and system output/mute. Initial observations do not sound alerts. **Communications instruments** controls decorative motion; Reduce Motion and hidden windows stop that motion. Lamp symbols and text preserve the useful status when effects are disabled.

## Profiles and limits

**Station → Export Station** saves versioned JSON containing the server and channels, disconnected. Tokens, readings, and log entries are excluded. **Station Setup → Import** loads a disconnected draft for review; Save is explicit. Files are limited to 64 KB. An unreadable saved profile is preserved and reported rather than silently overwritten.

This is a metrics viewer, not an OTLP receiver or a replacement for an observability backend. OpenTelemetry handles instrumentation and transport; send those metrics to a backend that exposes the supported Prometheus query API, then configure its metric names here. Traces, log ingestion, server discovery, alert-rule editing, and recorder control are outside this first version.

For the MotionStudies observer, see the [exporter example](../examples/communications/README.md). No production endpoint or credentials are bundled, and selecting the preset does not deploy or connect a server.

Protocol references: [Prometheus query API](https://prometheus.io/docs/prometheus/latest/querying/api/) and [OpenTelemetry signals](https://opentelemetry.io/docs/concepts/signals/).
