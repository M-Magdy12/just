#!/bin/bash

echo "======================================"
echo "E-commerce App Deployment Script"
echo "======================================"

# Variables
DOCKER_USERNAME="marwanhassan22"
APP_NAME="ecommerce-app"
VERSION="v1"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Build Docker image
echo -e "${YELLOW}Step 1: Building Docker image...${NC}"
docker build -t ${DOCKER_USERNAME}/${APP_NAME}:${VERSION} .

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Docker build failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker image built successfully${NC}"

# Step 2: Push to Docker Hub
echo -e "${YELLOW}Step 2: Logging into Docker Hub...${NC}"
docker login
echo -e "${YELLOW}Pushing image to Docker Hub...${NC}"
docker push ${DOCKER_USERNAME}/${APP_NAME}:${VERSION}

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Docker push failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Image pushed successfully${NC}"

# Step 3: Update image in deployment file
echo -e "${YELLOW}Step 3: Updating deployment configuration...${NC}"

sed -i "s|image: .*|image: ${DOCKER_USERNAME}/${APP_NAME}:${VERSION}|g" ecommerce-deployment.yaml

echo -e "${GREEN}✓ Configuration updated${NC}"

# Step 4: Deploy application
echo -e "${YELLOW}Step 4: Deploying to Kubernetes...${NC}"
kubectl apply -f ecommerce-deployment.yaml

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Deployment failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Application deployed${NC}"

# Step 5: Deploy ServiceMonitor
echo -e "${YELLOW}Step 5: Deploying ServiceMonitor...${NC}"
kubectl apply -f ecommerce-servicemonitor.yaml
echo -e "${GREEN}✓ ServiceMonitor deployed${NC}"

# Step 6: Deploy Alert Rules
echo -e "${YELLOW}Step 6: Deploying Alert Rules...${NC}"
kubectl apply -f ecommerce-alert-rules.yaml
echo -e "${GREEN}✓ Alert rules deployed${NC}"

# Step 7: Wait for pods to be ready
echo -e "${YELLOW}Step 7: Waiting for pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=${APP_NAME} --timeout=180s

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Pods not ready${NC}"
    kubectl get pods -l app=${APP_NAME}
    exit 1
fi
echo -e "${GREEN}✓ Pods are ready${NC}"

# Step 8: Get service information
echo -e "${YELLOW}Step 8: Service Information${NC}"
NODE_PORT=$(kubectl get svc ecommerce-service -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')

if [ -z "$NODE_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

echo -e "${GREEN}======================================"
echo "Deployment Completed Successfully!"
echo "======================================"
echo -e "Application URL: http://${NODE_IP}:${NODE_PORT}"
echo -e "Metrics URL: http://${NODE_IP}:${NODE_PORT}/metrics"
echo -e "Health Check: http://${NODE_IP}:${NODE_PORT}/health"
echo ""
echo "Test the application:"
echo "  curl http://${NODE_IP}:${NODE_PORT}/products"
echo "  curl http://${NODE_IP}:${NODE_PORT}/stats"
echo ""
echo "Check pods:"
echo "  kubectl get pods -l app=${APP_NAME}"
echo ""
echo "Watch logs:"
echo "  kubectl logs -l app=${APP_NAME} -f"
echo "======================================${NC}"
