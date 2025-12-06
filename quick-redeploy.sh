#!/bin/bash

echo "🔧 Fixing E-commerce App..."

# 1. Fix requirements.txt
cat > requirements.txt << 'EOF'
Flask==2.3.0
prometheus-flask-exporter==0.22.4
prometheus-client==0.19.0
werkzeug==2.3.0
EOF
echo "✅ Fixed requirements.txt"

# 2. Fix Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.9-slim

WORKDIR /app

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY index.html .

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

CMD ["python", "app.py"]
EOF
echo "✅ Fixed Dockerfile"

# 3. Build
echo "🏗️  Building Docker image..."
docker build -t marwanhassan22/ecommerce-app:v2 .

# 4. Push
echo "📤 Pushing to Docker Hub..."
docker push marwanhassan22/ecommerce-app:v2

# 5. Update deployment file
sed -i 's/:v1/:v2/g' ecommerce-deployment.yaml
echo "✅ Updated deployment file"

# 6. Redeploy
echo "🚀 Redeploying..."
kubectl delete deployment ecommerce-app
sleep 3
kubectl apply -f ecommerce-deployment.yaml

# 7. Watch
echo "👀 Watching pods..."
kubectl get pods -l app=ecommerce -w
