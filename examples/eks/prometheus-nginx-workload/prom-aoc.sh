#!/usr/bin/env bash

AOC_NAMESPACE=eks-aoc
TRAFFIC_NAMESPACE=eks-traffic
AWS_ID=<dummy>
AWS_SECRET=<dummy>
AWS_REGION=us-west-2

# exit when any command fails and propagate pipe errors
set -eo pipefail

err_report() {
    echo "Error on line $1: $BASH_COMMAND"
}

trap 'err_report ${LINENO}' ERR

function setup {
    printf "Initiating Prometheus AOC setup...\n\n"
    kubectl create namespace $AOC_NAMESPACE

    # Install NGINX Ingress Controller and enable Prometheus metrics
    helm install my-nginx ingress-nginx/ingress-nginx \
        --namespace $AOC_NAMESPACE \
        --set controller.metrics.enabled=true \
        --set-string controller.metrics.service.annotations."prometheus\.io/port"="10254" \
        --set-string controller.metrics.service.annotations."prometheus\.io/scrape"="true" \
        >/dev/null

    # Get external IP address of NGINX Ingress controller
    EXTERNAL_IP=$(kubectl get svc -n $AOC_NAMESPACE my-nginx-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    printf "\nNGINX Ingress Controller installed and exposed at: $EXTERNAL_IP.\n\n"

    # Attach AOC service
    cat examples/eks/prometheus-nginx-workload/eks-aoc-nginx.yaml |
        sed "s/{{namespace}}/$AOC_NAMESPACE/g" |
        sed "s/{{aws_id}}/$AWS_ID/g" |
        sed "s/{{aws_secret}}/$AWS_SECRET/g" |
        sed "s/{{region}}/$AWS_REGION/g" |
        kubectl apply -f -
    printf "\nAOC successfully installed.\n\n"
    
    # Set up sample traffic server
    curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/master/k8s-deployment-manifest-templates/deployment-mode/service/cwagent-prometheus/sample_traffic/nginx-traffic/nginx-traffic-sample.yaml |
        sed "s/{{external_ip}}/$EXTERNAL_IP/g" |
        sed "s/{{namespace}}/$TRAFFIC_NAMESPACE/g" |
        kubectl apply -f -
    printf "\nSample traffic server set up.\n\n"

    echo "Prometheus AOC setup complete!"
}

function teardown {
    printf "Initiating teardown sequence...\n\n"
    kubectl delete namespace $TRAFFIC_NAMESPACE
    helm uninstall my-nginx --namespace $AOC_NAMESPACE
    kubectl delete namespace $AOC_NAMESPACE
}

subcommand=$1
case "$subcommand" in
    "")
        setup
        ;;
    --teardown | -t)
        teardown
        ;;
    *)
        echo "Invalid command: $subcommand"
        exit 1
        ;;
esac
