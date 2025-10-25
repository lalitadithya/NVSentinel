module github.com/nvidia/nvsentinel/store-client-sdk

go 1.24.0

toolchain go1.24.8

require (
	github.com/stretchr/testify v1.11.1
	go.mongodb.org/mongo-driver v1.17.4
	k8s.io/klog/v2 v2.130.1
)

require (
	github.com/davecgh/go-spew v1.1.2-0.20180830191138-d8f796af33cc // indirect
	github.com/go-logr/logr v1.4.3 // indirect
	github.com/golang/snappy v1.0.0 // indirect
	github.com/google/go-cmp v0.7.0 // indirect
	github.com/klauspost/compress v1.18.0 // indirect
	github.com/kr/pretty v0.3.1 // indirect
	github.com/montanaflynn/stats v0.7.1 // indirect
	github.com/pmezard/go-difflib v1.0.1-0.20181226105442-5d4384ee4fb2 // indirect
	github.com/rogpeppe/go-internal v1.14.1 // indirect
	github.com/xdg-go/pbkdf2 v1.0.0 // indirect
	github.com/xdg-go/scram v1.1.2 // indirect
	github.com/xdg-go/stringprep v1.0.4 // indirect
	github.com/youmark/pkcs8 v0.0.0-20240726163527-a2c0da244d78 // indirect
	golang.org/x/crypto v0.43.0 // indirect
	golang.org/x/sync v0.17.0 // indirect
	golang.org/x/text v0.30.0 // indirect
	gopkg.in/check.v1 v1.0.0-20201130134442-10cb98267c6c // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

// Local replacements for internal modules
replace github.com/nvidia/nvsentinel/data-models => ../data-models

replace github.com/nvidia/nvsentinel/statemanager => ../statemanager

replace github.com/nvidia/nvsentinel/health-monitors/csp-health-monitor => ../health-monitors/csp-health-monitor

replace github.com/nvidia/nvsentinel/health-monitors/syslog-health-monitor => ../health-monitors/syslog-health-monitor

replace github.com/nvidia/nvsentinel/platform-connectors => ../platform-connectors

replace github.com/nvidia/nvsentinel/health-event-client => ../health-event-client

replace github.com/nvidia/nvsentinel/health-events-analyzer => ../health-events-analyzer

replace github.com/nvidia/nvsentinel/fault-quarantine-module => ../fault-quarantine-module

replace github.com/nvidia/nvsentinel/labeler-module => ../labeler-module

replace github.com/nvidia/nvsentinel/node-drainer-module => ../node-drainer-module

replace github.com/nvidia/nvsentinel/fault-remediation-module => ../fault-remediation-module
