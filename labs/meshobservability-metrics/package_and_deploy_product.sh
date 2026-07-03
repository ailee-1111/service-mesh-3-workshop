#!/bin/bash
podman login -u developer -p developer registry.ocp4.example.com:8443
podman build -t registry.ocp4.example.com:8443/developer/ossm-metrics-product:1.0 /home/student/course/labs/meshobservability-metrics/product
podman push registry.ocp4.example.com:8443/developer/ossm-metrics-product:1.0
oc apply -f /home/student/course/labs/meshobservability-metrics/product-deploy.yaml -n meshobservability-metrics
