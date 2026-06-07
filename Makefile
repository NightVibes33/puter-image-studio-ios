.PHONY: api-health api-start xcodegen verify-static security-scan

api-health:
	curl -sS http://127.0.0.1:8787/health

api-start:
	node --no-jitless /root/puter-api-proof/server.js

xcodegen:
	xcodegen generate

verify-static:
	python3 Scripts/verify_static.py

security-scan:
	! rg -n "try!|as!|fatalError|NSAllowsArbitraryLoads|PUTER_AUTH_TOKEN|api\\.puter\\.com|WKWebView|WebView" Sources Tests
