# E-commerce Application Deployment Guide

## 📋 Overview
E-commerce web application بسيط مع Flask backend و SQLite database مع Prometheus monitoring كامل.

## 🏗️ Architecture
- **Backend**: Flask (Python)
- **Database**: SQLite (embedded في الـ container)
- **Monitoring**: Prometheus + Grafana
- **Deployment**: Kubernetes (2 replicas)
- **Alerts**: AlertManager

## 📦 Files Structure
```
.
├── app.py                          # Flask application
├── requirements.txt                # Python dependencies
├── Dockerfile                      # Container image
├── ecommerce-deployment.yaml       # K8s Deployment + Service
├── ecommerce-servicemonitor.yaml   # Prometheus ServiceMonitor
├── ecommerce-alert-rules.yaml      # Alert rules
├── deploy-ecommerce.sh             # Deployment script
└── test-ecommerce.sh               # Testing script
```

## 🚀 Deployment Steps

### 1. Prerequisites
```bash
# تأكد إن Docker و kubectl شغالين
docker --version
kubectl version --client

# تأكد إنك متصل بالـ cluster
kubectl get nodes
```

### 2. إعداد الملفات
```bash
# إنشاء مجلد للـ project
mkdir ecommerce-app
cd ecommerce-app

# نسخ كل الملفات اللي فوق في المجلد ده
```

### 3. تعديل Docker Hub Username
```bash
# في ملف deploy-ecommerce.sh
# غير السطر ده:
DOCKER_USERNAME="your-dockerhub-username"
# حطه بـ username بتاعك على Docker Hub

# في ملف ecommerce-deployment.yaml
# غير السطر ده:
image: your-dockerhub-username/ecommerce-app:latest
```

### 4. Build و Deploy
```bash
# إعطاء صلاحيات للـ scripts
chmod +x deploy-ecommerce.sh test-ecommerce.sh

# تشغيل الـ deployment
./deploy-ecommerce.sh
```

### 5. Verify Deployment
```bash
# التأكد من الـ pods
kubectl get pods -l app=ecommerce

# التأكد من الـ service
kubectl get svc ecommerce-service

# شوف الـ logs
kubectl logs -l app=ecommerce -f
```

### 6. Test Application
```bash
# تشغيل الـ testing script
./test-ecommerce.sh
```

## 🔍 Monitoring Setup

### 1. Verify Prometheus Scraping
```bash
# دخول على Prometheus UI
# افتح Prometheus وروح على Status > Targets
# لازم تلاقي "ecommerce-service" موجود ومكتوب قدامه UP

# أو من command line:
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090

# فتح في المتصفح: http://localhost:9090
# روح Targets وشوف ecommerce-service
```

### 2. Check Metrics
```bash
# جرب metrics في Prometheus
# اكتب في Query:
flask_http_request_total
flask_http_request_duration_seconds_sum
up{job="ecommerce-service"}
```

### 3. Grafana Dashboard
```bash
# دخول Grafana
kubectl port-forward svc/prometheus-grafana 3000:80

# افتح: http://localhost:3000
# Username: admin
# Password: شوفه من secret:
kubectl get secret prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

#### إنشاء Dashboard للـ E-commerce:
1. روح **Create** > **Dashboard**
2. **Add visualization**
3. Data source: **Prometheus**
4. استخدم الـ queries دي:

**Panel 1: Request Rate**
```promql
rate(flask_http_request_total[5m])
```

**Panel 2: Error Rate**
```promql
rate(flask_http_request_total{status=~"5.."}[5m])
```

**Panel 3: Response Time**
```promql
flask_http_request_duration_seconds_sum / flask_http_request_duration_seconds_count
```

**Panel 4: Active Pods**
```promql
up{job="ecommerce-service"}
```

**Panel 5: Memory Usage**
```promql
container_memory_usage_bytes{pod=~"ecommerce-app-.*"}
```

**Panel 6: CPU Usage**
```promql
rate(container_cpu_usage_seconds_total{pod=~"ecommerce-app-.*"}[5m])
```

### 4. Alerts Configuration
الـ alerts بتتبعت لـ AlertManager ومنه لـ Slack:

```bash
# التأكد من الـ alert rules
kubectl get prometheusrules ecommerce-alerts

# شوف الـ alerts في Prometheus UI
# روح على: Alerts tab
```

## 📊 Available Endpoints

### Application Endpoints
```bash
GET  /health              # Health check
GET  /products            # Get all products
GET  /products/<id>       # Get single product
POST /orders              # Create order
GET  /orders              # Get all orders
GET  /stats               # Get statistics
GET  /metrics             # Prometheus metrics
```

### API Examples
```bash
# Get products
curl http://NODE_IP:30080/products

# Get product by ID
curl http://NODE_IP:30080/products/1

# Create order
curl -X POST http://NODE_IP:30080/orders \
  -H "Content-Type: application/json" \
  -d '{"product_id": 1, "quantity": 2}'

# Get statistics
curl http://NODE_IP:30080/stats
```

## 🔔 Alert Rules
الـ application بيبعت alerts للحالات دي:

1. **EcommerceAppDown**: لو الـ app وقع
2. **HighErrorRate**: لو في error rate عالي
3. **HighResponseTime**: لو response time بطيء
4. **HighMemoryUsage**: لو memory usage > 85%
5. **HighCPUUsage**: لو CPU usage > 80%
6. **PodRestarting**: لو الـ pods بتعمل restart كتير
7. **LowRequestRate**: لو في traffic قليل جداً

## 🔧 Troubleshooting

### Pods not starting
```bash
# شوف الـ events
kubectl describe pod -l app=ecommerce

# شوف الـ logs
kubectl logs -l app=ecommerce
```

### Metrics not appearing
```bash
# تأكد إن ServiceMonitor موجود
kubectl get servicemonitor ecommerce-monitor

# تأكد من الـ annotations في الـ service
kubectl get svc ecommerce-service -o yaml | grep prometheus
```

### Alerts not firing
```bash
# شوف الـ PrometheusRule
kubectl get prometheusrule ecommerce-alerts -o yaml

# تأكد إن Prometheus شايف الـ rules
# روح على Prometheus UI > Alerts
```

## 📈 Scaling

### Scale pods
```bash
# زود عدد الـ replicas
kubectl scale deployment ecommerce-app --replicas=3

# Auto-scaling (HPA)
kubectl autoscale deployment ecommerce-app \
  --cpu-percent=70 \
  --min=2 \
  --max=5
```

## 🧹 Cleanup

### حذف الـ application
```bash
kubectl delete -f ecommerce-deployment.yaml
kubectl delete -f ecommerce-servicemonitor.yaml
kubectl delete -f ecommerce-alert-rules.yaml
```

### حذف الـ Docker image
```bash
docker rmi your-dockerhub-username/ecommerce-app:latest
```

## 📝 Notes

- الـ database (SQLite) موجود داخل الـ pod، فلو الـ pod اتحذف الـ data هتروح
- لو عايز data persistent، استخدم PersistentVolume
- الـ app بيخلق sample data لما يبدأ لأول مرة
- الـ NodePort 30080 ممكن تغيره في الـ deployment file
- Prometheus بيعمل scrape كل 15 ثانية

## 🎯 Next Steps

1. ✅ Deploy application
2. ✅ Configure monitoring
3. ✅ Set up alerts
4. 📊 Create Grafana dashboards
5. 🔄 Test auto-scaling
6. 🔒 Add authentication (optional)
7. 💾 Add persistent storage (optional)

---

**Happy Monitoring! 🚀**
