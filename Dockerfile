FROM python:3.11-slim

WORKDIR /app

# Install curl for healthcheck, then clean up
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app
COPY . .

# Create data and models directories
RUN mkdir -p data models

# Create non-root user and give ownership
RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser && \
    chown -R appuser:appuser /app
USER appuser

# Expose port (internal only — no host binding)
EXPOSE 8080

# Run with gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--threads", "4", "--timeout", "120", "app:app"]
