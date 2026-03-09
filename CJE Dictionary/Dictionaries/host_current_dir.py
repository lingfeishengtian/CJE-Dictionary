#!/usr/bin/env python3

import argparse
import time
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler


PRESETS = {
    "edge": {"latency_ms": 600, "kbps": 30},
    "3g": {"latency_ms": 300, "kbps": 200},
    "4g": {"latency_ms": 80, "kbps": 1500},
}


class SlowHandler(SimpleHTTPRequestHandler):
    latency_ms = 0
    kbps = 0

    def _apply_latency(self) -> None:
        if self.latency_ms > 0:
            time.sleep(self.latency_ms / 1000)

    def do_GET(self) -> None:
        self._apply_latency()
        super().do_GET()

    def do_HEAD(self) -> None:
        self._apply_latency()
        super().do_HEAD()

    def copyfile(self, source, outputfile) -> None:
        if self.kbps <= 0:
            super().copyfile(source, outputfile)
            return

        bytes_per_second = self.kbps * 1024
        chunk_size = 16 * 1024

        while True:
            chunk = source.read(chunk_size)
            if not chunk:
                break

            outputfile.write(chunk)
            outputfile.flush()
            time.sleep(len(chunk) / bytes_per_second)


def main() -> None:
    parser = argparse.ArgumentParser(description="Host current directory over HTTP")
    parser.add_argument("--host", default="0.0.0.0", help="Bind host (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=8000, help="Bind port (default: 8000)")
    parser.add_argument(
        "--preset",
        choices=sorted(PRESETS.keys()),
        help="Network preset: edge, 3g, 4g",
    )
    parser.add_argument(
        "--latency-ms",
        type=int,
        help="Artificial delay per request in milliseconds (overrides preset)",
    )
    parser.add_argument(
        "--kbps",
        type=int,
        help="Throttle response speed in KB/s (overrides preset; 0 = unlimited)",
    )
    args = parser.parse_args()

    preset_values = PRESETS.get(args.preset, {"latency_ms": 0, "kbps": 0})

    latency_ms = preset_values["latency_ms"] if args.latency_ms is None else args.latency_ms
    kbps = preset_values["kbps"] if args.kbps is None else args.kbps

    SlowHandler.latency_ms = max(0, latency_ms)
    SlowHandler.kbps = max(0, kbps)

    with ThreadingHTTPServer((args.host, args.port), SlowHandler) as server:
        print(f"Serving current directory on http://localhost:{args.port}")
        print(f"Preset: {args.preset or 'custom'}")
        print(
            f"Slow mode: latency={SlowHandler.latency_ms}ms, bandwidth="
            f"{'unlimited' if SlowHandler.kbps == 0 else f'{SlowHandler.kbps} KB/s'}"
        )
        print("Press Ctrl+C to stop.")
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nServer stopped.")


if __name__ == "__main__":
    main()
