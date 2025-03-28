#! /usr/bin/env python3
#
# A mock remote pg_service server, designed to be invoked from
# PgRemoteService/Server.pm. This listens on an ephemeral port number (printed to stdout
# so that the Perl tests can contact it) and runs as a daemon until it is
# signaled.
#

import base64
import http.server
import json
import os
import sys
import time
import urllib.parse


class OAuthHandler(http.server.BaseHTTPRequestHandler):
    """
    Core implementation of the authorization server. The API is
    inheritance-based, with entry points at do_GET() and do_POST(). See the
    documentation for BaseHTTPRequestHandler.
    """

    JsonObject = dict[str, object]  # TypeAlias is not available until 3.10


    def do_GET(self):
        self._response_code = 200

        self._send_service_file()

    def _send_service_file(self) -> None:
        """
        Sends the provided JSON dict as an application/json response.
        self._response_code can be modified to send JSON error responses.
        """
        resp = json.dumps(js).encode("ascii")
        self.log_message("sending JSON response: %s", resp)

        self.send_response(self._response_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(resp)))
        self.end_headers()

        self.wfile.write(resp)

    def config(self) -> JsonObject:
        port = self.server.socket.getsockname()[1]

        issuer = f"http://127.0.0.1:{port}"
        if self._alt_issuer:
            issuer += "/alternate"
        elif self._parameterized:
            issuer += "/param"

        return {
            "issuer": issuer,
            "token_endpoint": issuer + "/token",
            "device_authorization_endpoint": issuer + "/authorize",
            "response_types_supported": ["token"],
            "subject_types_supported": ["public"],
            "id_token_signing_alg_values_supported": ["RS256"],
            "grant_types_supported": [
                "authorization_code",
                "urn:ietf:params:oauth:grant-type:device_code",
            ],
        }

    @property
    def _token_state(self):
        """
        A cached _TokenState object for the connected client (as determined by
        the request's client_id), or a new one if it doesn't already exist.

        This relies on the existence of a defaultdict attached to the server;
        see main() below.
        """
        return self.server.token_state[self.client_id]

    def _remove_token_state(self):
        """
        Removes any cached _TokenState for the current client_id. Call this
        after the token exchange ends to get rid of unnecessary state.
        """
        if self.client_id in self.server.token_state:
            del self.server.token_state[self.client_id]

    def authorization(self) -> JsonObject:
        uri = "https://example.com/"
        if self._alt_issuer:
            uri = "https://example.org/"

        resp = {
            "device_code": "postgres",
            "user_code": "postgresuser",
            self._uri_spelling: uri,
            "expires_in": 5,
            **self._response_padding,
        }

        interval = self._interval
        if interval is not None:
            resp["interval"] = interval
            self._token_state.min_delay = interval
        else:
            self._token_state.min_delay = 5  # default

        # Check the scope.
        if "scope" in self._params:
            assert self._params["scope"][0], "empty scopes should be omitted"

        return resp

    def token(self) -> JsonObject:
        if err := self._get_param("error_code", None):
            self._response_code = self._get_param("error_status", 400)

            resp = {"error": err}
            if desc := self._get_param("error_desc", ""):
                resp["error_description"] = desc

            return resp

        if self._should_modify() and "retries" in self._test_params:
            retries = self._test_params["retries"]

            # Check to make sure the token interval is being respected.
            now = time.monotonic()
            if self._token_state.last_try is not None:
                delay = now - self._token_state.last_try
                assert (
                    delay > self._token_state.min_delay
                ), f"client waited only {delay} seconds between token requests (expected {self._token_state.min_delay})"

            self._token_state.last_try = now

            # If we haven't reached the required number of retries yet, return a
            # "pending" response.
            if self._token_state.retries < retries:
                self._token_state.retries += 1

                self._response_code = 400
                return {"error": self._retry_code}

        # Clean up any retry tracking state now that the exchange is ending.
        self._remove_token_state()

        return {
            "access_token": self._access_token,
            "token_type": "bearer",
            **self._response_padding,
        }


def main():
    """
    Starts the PgRemoteService server on localhost. The ephemeral port in use will
    be printed to stdout.
    """

    s = http.server.HTTPServer(("127.0.0.1", 0), OAuthHandler)

    # Give the parent the port number to contact (this is also the signal that
    # we're ready to receive requests).
    port = s.socket.getsockname()[1]
    print(port)

    # stdout is closed to allow the parent to just "read to the end".
    stdout = sys.stdout.fileno()
    sys.stdout.close()
    os.close(stdout)

    s.serve_forever()  # we expect our parent to send a termination signal


if __name__ == "__main__":
    main()
