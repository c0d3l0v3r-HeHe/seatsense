# SeatSense: API + Flutter web app in one container. Needs no raw data: it serves the
# crowding tables in outputs/crowding/ (built by scripts/build_all.sh and committed).
FROM python:3.12-slim

WORKDIR /srv
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PYTHONPATH=/srv/src PORT=8000

COPY requirements-serve.txt .
RUN pip install --no-cache-dir -r requirements-serve.txt

# Pre-built Flutter web app, attached to the GitHub release
# (cd app && flutter build web --release --no-web-resources-cdn, minus *.symbols).
ARG WEB_URL=https://github.com/c0d3l0v3r-HeHe/seatsense/releases/download/v1.0-phase1/seatsense-web.tar.gz
ADD ${WEB_URL} /tmp/web.tar.gz
RUN mkdir -p app/build/web && tar -xzf /tmp/web.tar.gz -C app/build/web && rm /tmp/web.tar.gz \
 && find app/build/web -path app/build/web/assets -prune -o -type f \( -name '*.js' -o -name '*.wasm' -o -name '*.json' \) \
    -size +1k -exec gzip -9 -k {} +   # served pre-compressed, so a slow CPU never gzips on request

COPY src/crowding/ src/crowding/
COPY outputs/crowding/ outputs/crowding/
COPY outputs/validation.json outputs/

RUN useradd --create-home app && chown -R app /srv
USER app
EXPOSE 8000
CMD ["python", "-m", "crowding.api"]
