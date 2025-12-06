المرحلة الأولى: Build stage,
FROM python:3.9-slim as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

المرحلة الثانية: Runtime stage,
FROM python:3.9-slim
WORKDIR /app



نسخ الـ Python packages من الـ builder stage,
COPY --from=builder /root/.local /root/.local

نسخ ملفات التطبيق,
COPY app.py .
COPY index.html .

التأكد من أن الـ Python packages في الـ PATH,
ENV PATH=/root/.local/bin:$PATH

EXPOSE 5000

CMD ["python", "app.py"]
