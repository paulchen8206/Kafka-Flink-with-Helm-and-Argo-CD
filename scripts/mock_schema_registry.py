#!/usr/bin/env python3
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

KNOWN_SUBJECTS = [
    "raw_sales_orders-value",
    "sales_order-value",
    "sales_order_line_item-value",
    "customer_sales-value",
    "mdm_customer-value",
    "mdm_product-value",
]

AVRO_SCHEMA = json.dumps(
    {
        "type": "record",
        "name": "OpenMetadataTopicValue",
        "namespace": "local.schema",
        "fields": [{"name": "id", "type": "string"}],
    }
)


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, payload, status=200):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/vnd.schemaregistry.v1+json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = self.path
        if path == "/subjects":
            self._send_json(KNOWN_SUBJECTS)
            return

        if path.startswith("/subjects/") and path.endswith("/versions/latest"):
            subject = path[len("/subjects/") : -len("/versions/latest")]
            if subject.startswith("/"):
                subject = subject[1:]
            if subject not in KNOWN_SUBJECTS:
                # Return an empty schema object instead of 404 to avoid noisy client warnings.
                subject = "unknown-value"
            self._send_json(
                {
                    "subject": subject,
                    "version": 1,
                    "id": 1,
                    "schemaType": "AVRO",
                    "schema": AVRO_SCHEMA,
                    "references": [],
                }
            )
            return

        self._send_json({"message": "not found"}, status=404)

    def log_message(self, format, *args):
        return


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 8081), Handler)
    server.serve_forever()
