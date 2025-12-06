# المرحلة الأولى: Build stage
FROM python:3.9-slim as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# المرحلة الثانية: Runtime stage
FROM python:3.9-slim
WORKDIR /app

# تثبيت curl فقط للـ healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# نسخ الـ Python packages من الـ builder stage
COPY --from=builder /root/.local /root/.local

# نسخ ملفات التطبيق
COPY app.py .
COPY index.html .

# التأكد من أن الـ Python packages في الـ PATH
ENV PATH=/root/.local/bin:$PATH

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

CMD ["python", "app.py"]